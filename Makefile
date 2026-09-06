# NeoOS OpenSSL 3.5.8 build

MUSL_DIR ?= ../neoos-musl/build-output
PREFIX ?= build-output
UPSTREAM_DIR ?= upstream

.PHONY: all clean verify help submodule-init

all: build-output/lib/libssl.a

submodule-init:
	@if [ ! -f "$(UPSTREAM_DIR)/Configure" ]; then \
		echo "Initializing upstream submodule..."; \
		git submodule update --init upstream; \
	fi

build-output/lib/libssl.a: submodule-init
	@[ -d "$(MUSL_DIR)/include" ] || { \
		echo "Error: musl not found at $(MUSL_DIR) -- build neoos-musl first"; \
		exit 1; \
	}
	@MUSL_DIR="$(MUSL_DIR)" PREFIX="$(PREFIX)" ./build.sh

clean:
	rm -rf $(PREFIX)
	cd $(UPSTREAM_DIR) && git clean -fdx && git checkout .

verify:
	@if [ -f "$(PREFIX)/lib/libssl.a" ] && [ -f "$(PREFIX)/lib/libcrypto.a" ]; then \
		echo "OK libssl.a/libcrypto.a built"; \
	else \
		echo "ERROR libssl.a/libcrypto.a not found"; \
		exit 1; \
	fi

help:
	@echo "NeoOS OpenSSL 3.5.8 build"
	@echo "Usage: make [MUSL_DIR=path]"
