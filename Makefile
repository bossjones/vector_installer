# -*- coding: utf-8 -*-
# SOURCE: https://github.com/autopilotpattern/jenkins/blob/master/makefile
MAKEFLAGS += --warn-undefined-variables
# .SHELLFLAGS := -eu -o pipefail

# SOURCE: https://github.com/luismayta/zsh-servers-functions/blob/b68f34e486d6c4a465703472e499b1c39fe4a26c/Makefile
# Configuration.
SHELL = /bin/bash
ROOT_DIR = $(shell pwd)

MAKE := make

config:
	git pull --rebase && \
	cp -a vector/vector.yaml /etc/vector/vector.yaml && \
	systemctl restart vector && \
	journalctl -f | ccze -A

graph:
	vector graph --config ./vector/vector.yaml | dot -Tsvg > graph.svg

update:
	./update-systemd-and-config.sh

redo:
	git pull --rebase
	$(MAKE) update;
	tail -f /tmp/*.log | ccze -A

status:
	systemctl status vector

validate:
	vector graph --config ./vector/vector.yaml
