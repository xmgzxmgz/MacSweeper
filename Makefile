# MacSweeper (Mac 清风) Makefile
# Provides convenient build commands for the project

SWIFT := swift
BUILD_DIR := .build
RELEASE_BIN := $(BUILD_DIR)/release
DEBUG_BIN := $(BUILD_DIR)/debug

.PHONY: all cli app debug release clean help install

all: release

## Build CLI tool (release)
cli:
	@echo "Building MacSweeperCLI (release)..."
	$(SWIFT) build -c release --product MacSweeperCLI
	@echo "Done: $(RELEASE_BIN)/MacSweeperCLI"

## Build GUI app (release, requires Xcode)
app:
	@echo "Building MacSweeperApp (release)..."
	$(SWIFT) build -c release --product MacSweeperApp
	@echo "Done: $(RELEASE_BIN)/MacSweeperApp"

## Build all targets (release)
release:
	@echo "Building all targets (release)..."
	$(SWIFT) build -c release
	@echo "Done. Binaries in $(RELEASE_BIN)/"

## Build all targets (debug)
debug:
	@echo "Building all targets (debug)..."
	$(SWIFT) build
	@echo "Done. Binaries in $(DEBUG_BIN)/"

## Build CLI and run with arguments
run-cli: cli
	$(RELEASE_BIN)/MacSweeperCLI $(ARGS)

## Run CLI with --help
help-cli: cli
	$(RELEASE_BIN)/MacSweeperCLI --help

## Run CLI quick scan of current directory
scan: cli
	$(RELEASE_BIN)/MacSweeperCLI .

## Install CLI to /usr/local/bin
install: cli
	@echo "Installing MacSweeperCLI to /usr/local/bin..."
	install -d /usr/local/bin
	install -m 755 $(RELEASE_BIN)/MacSweeperCLI /usr/local/bin/MacSweeperCLI
	@echo "Installed. Run 'MacSweeperCLI --help' to get started."

## Uninstall CLI from /usr/local/bin
uninstall:
	rm -f /usr/local/bin/MacSweeperCLI
	@echo "Uninstalled."

## Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)
	@echo "Clean."

## Show build logs (useful for debugging)
log:
	$(SWIFT) build 2>&1 | tail -40

## Display this help
help:
	@echo "MacSweeper (Mac 清风) Build Commands"
	@echo "======================================"
	@echo "  make cli        Build CLI tool (release)"
	@echo "  make app        Build GUI app (release)"
	@echo "  make release    Build all targets (release)"
	@echo "  make debug      Build all targets (debug)"
	@echo "  make run-cli    Build & run CLI (pass ARGS='...')"
	@echo "  make help-cli   Show CLI help"
	@echo "  make scan       Quick scan current directory"
	@echo "  make install    Install CLI to /usr/local/bin"
	@echo "  make uninstall  Remove CLI from /usr/local/bin"
	@echo "  make clean      Clean build artifacts"
	@echo "  make log        Show recent build output"
	@echo ""
	@echo "Examples:"
	@echo "  make run-cli ARGS='~/Downloads --large=500MB'"
	@echo "  make scan"
