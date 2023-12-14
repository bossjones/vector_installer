config:
	git pull --rebase && \
	cp -a vector/vector.yaml /etc/vector/vector.yaml && \
	systemctl restart vector && \
	journalctl -f | ccze -A
