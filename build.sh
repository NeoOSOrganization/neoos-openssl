#!/bin/bash
set -e

MUSL_DIR="${MUSL_DIR:-../neoos-musl/build-output}"
CC="${CC:-x86_64-elf-gcc}"
PREFIX="${PREFIX:-build-output}"
UPSTREAM_DIR="${UPSTREAM_DIR:-upstream}"

if [ ! -d "$MUSL_DIR/include" ]; then
    echo "Error: musl not found at $MUSL_DIR (build neoos-musl first)" >&2
    exit 1
fi
if [ ! -f "$UPSTREAM_DIR/Configure" ]; then
    echo "Error: upstream OpenSSL checkout not found at $UPSTREAM_DIR" >&2
    exit 1
fi

ABS_PREFIX="$(mkdir -p "$PREFIX" && cd "$PREFIX" && pwd)"
ABS_MUSL_DIR="$(cd "$MUSL_DIR" && pwd)"

echo "Building OpenSSL 1.1.1 for NeoOS..."
cd "$UPSTREAM_DIR"

# linux-x86_64, not a NeoOS-specific target: it only assumes libc
# functions musl already provides, never Linux syscall numbers
# directly (those are musl's own shim's problem). Alpine Linux proves
# this combination works -- real OpenSSL, built with this exact
# target, against musl. See docs/superpowers/specs/
# 2026-09-06-openssl-port-design.md section 4 (neoos-kernel repo).
./Configure linux-x86_64 \
    --cross-compile-prefix=x86_64-elf- \
    no-shared no-dso no-dynamic-engine no-tests \
    --openssldir=/etc/ssl \
    --prefix="$ABS_PREFIX" \
    -isystem "$ABS_MUSL_DIR/include" \
    -static -nostdlib -mcmodel=large -fno-pic -mno-red-zone -fno-stack-protector -O2

# x86_64-elf-gcc is a bare-metal target -- its driver has no "linux"
# OS component at all, so it doesn't recognize -pthread as a flag
# (unlike a full linux-gnu/linux-musl cross-gcc, which bakes in a real
# spec for it). This is NOT a loss of threading support: musl's
# libc.a provides real pthread symbols unconditionally, no special
# compile/link flag required (unlike glibc, which uses -pthread for
# additional internal behavior musl doesn't need). Strip only the
# flag string the driver rejects; everything else Configure decided
# about threading (OPENSSL_THREADS, crypto/threads_pthread.c) is
# untouched.
sed -i 's/-pthread//g' Makefile

# build_libs only -- NOT `all`/`build_programs`. The apps/openssl CLI
# link step needs -ldl resolved against $MUSL_DIR/lib (its own LDFLAGS
# don't include that -L), and this port explicitly does not attempt a
# NeoOS-native openssl CLI at all (see docs/superpowers/specs/
# 2026-09-06-openssl-port-design.md's refinement note, neoos-kernel
# repo) -- building it would be pure wasted effort, not a real gap.
make -j"$(nproc)" build_libs
# install_dev alone (not install_sw, which pulls in install_runtime ->
# install_programs -> the apps/openssl CLI link this port deliberately
# skips): headers + libs + pkgconfig, depending only on
# install_runtime_libs -> build_libs above. install_ssldirs is NOT
# run: its recipe writes to the REAL $(OPENSSLDIR) (a known DESTDIR
# quirk in 1.1.1's install target -- it does not consistently prefix
# with $(DESTDIR)) which for a cross-build means the HOST's actual
# /etc/ssl. Unneeded anyway: the cert bundle this port cares about is
# staged directly below, into $PREFIX, not the host filesystem.
make install_dev

cd ..
mkdir -p "$PREFIX/etc/ssl"
cp cacert.pem "$PREFIX/etc/ssl/cert.pem"

if [ -f "$PREFIX/lib/libssl.a" ] && [ -f "$PREFIX/lib/libcrypto.a" ]; then
    echo ""
    echo "OK OpenSSL built successfully at $PREFIX"
    ls -lh "$PREFIX/lib/libssl.a" "$PREFIX/lib/libcrypto.a"
else
    echo "ERROR: build finished but libssl.a/libcrypto.a not found" >&2
    exit 1
fi
