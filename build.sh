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

make -j"$(nproc)"
make install_sw install_ssldirs

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
