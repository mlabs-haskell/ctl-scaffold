SHELL := bash
.ONESHELL:
.PHONY: autogen-deps
.SHELLFLAGS := -eu -o pipefail -c

ps-sources := $$(find ./* -iregex '.*.purs')

autogen-deps:
	spago2nix generate \
		&& node2nix -l package-lock.json -d -c node2nix.nix \
		&& ./nix/autogen-warning.sh

check-format:
	purs-tidy check ${ps-sources}

format:
	purs-tidy format-in-place ${ps-sources}
