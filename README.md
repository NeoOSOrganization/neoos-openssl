# NeoOS OpenSSL

OpenSSL 1.1.1 (pinned to `OpenSSL_1_1_1w`, the final 1.1.1 release),
built for NeoOS: static `libssl.a`/`libcrypto.a`, with real
certificate-chain verification against a bundled CA store (curl's own
published `cacert.pem`).

The shared TLS dependency the `neoos-curl` and `neoos-wget` ports each
link against. A NeoOS-native `openssl` CLI binary is NOT produced by
this repo (linking all of `upstream/apps/*.c` against a freestanding
target is a real, separately-sized problem) — verified instead by a
small test program exercising the public `SSL_CTX`/`SSL_connect` API
directly, which is also the exact way curl/wget consume these
libraries.

## Quick Start

Build musl first (`neoos-musl`), then:

```sh
make MUSL_DIR=../neoos-musl/build-output
# Produces: build-output/lib/{libssl,libcrypto}.a,
#           build-output/include/openssl/*.h,
#           build-output/etc/ssl/cert.pem
```

## Why `linux-x86_64` and not a NeoOS-specific target

OpenSSL's `Configure` is a Perl script consulting a static table of
named targets — unlike autoconf, it never probes the compiler by
running test programs. The `linux-x86_64` entry only assumes libc
functions musl already provides, never Linux syscall numbers directly
(that translation is `neoos-musl`'s own shim's job). Alpine Linux, a
real musl-based distribution, builds real OpenSSL packages with
exactly this target today — the existing proof this combination works
before NeoOS attempts it.

## Documentation

- **Design spec:** [neoos-kernel's
  docs/superpowers/specs/2026-09-06-openssl-port-design.md](https://github.com/NeoOSOrganization/neoos-kernel/blob/main/docs/superpowers/specs/2026-09-06-openssl-port-design.md)

## In This Organization

- **[neoos-kernel](https://github.com/NeoOSOrganization/neoos-kernel)** — Kernel source
- **[neoos-musl](https://github.com/NeoOSOrganization/neoos-musl)** — musl libc (this repo's build dependency)
- **[neoos-docs](https://github.com/NeoOSOrganization/neoos-docs)** — Guides and architecture
