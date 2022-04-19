SHELL := bash
.ONESHELL:
.PHONY: autogen-deps
.SHELLFLAGS := -eu -o pipefail -c

ps-sources := $$(fd -epurs)

check-format:
	purs-tidy check ${ps-sources}

format:
	purs-tidy format-in-place ${ps-sources}
