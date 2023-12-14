config:
	git pull --rebase && \
	cp -a vector/vector.yaml /etc/vector/vector.yaml && \
	systemctl restart vector && \
	journalctl -f | ccze -A

graph:
	vector graph --config ./vector/vector.yaml | dot -Tsvg > graph.svg

update:
	./update-systemd-and-config.sh
