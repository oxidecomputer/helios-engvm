#
# Copyright 2024 Oxide Computer Company
#

TOP =			$(PWD)

ENGVM_BUILD =		$(TOP)/../tools/engvm-build/target/debug/engvm-build

.PHONY: welcome
welcome: gmakecheck
	@printf '\n'
	@printf 'Welcome!\n'
	@printf '\n'
	@printf '\n'
	@if ! cargo --version >/dev/null 2>&1; then \
		printf '    You must install Rust before continuing.\n'; \
	else \
		printf '    Try "gmake setup" to get started!\n'; \
	fi
	@printf '\n'

.PHONY: gmakecheck
gmakecheck:
	@if [[ -z "$(.FEATURES)" ]]; then \
		printf 'ERROR: This Makefile requires GNU Make (gmake)\n' >&2; \
		exit 1; \
	fi

.PHONY: setup
setup: gmakecheck $(ENGVM_BUILD)
	@$(ENGVM_BUILD) setup
	rm -f engvm-build
	ln -s ../tools/engvm-build/target/debug/engvm-build
	@printf '\n'
	@printf 'Setup complete!  ./engvm-build is now available.\n'
	@printf '\n'

.PHONY: $(ENGVM_BUILD)
$(ENGVM_BUILD):
	@if [[ $$(/usr/bin/uname -o) != illumos ]]; then \
		printf 'ERROR: must be built on illumos\n' >&2; \
		exit 1; \
	fi
	cd ../tools/engvm-build && cargo build --quiet

.PHONY: clean
clean:
	cd ../tools/engvm-build && cargo clean --quiet
