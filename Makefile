# targets prefixed with underscore are not intended be invoked by human

.DEFAULT_GOAL := binaries
IMAGE         := ghcr.io/tomaszpolachowski/usernetes:latest
BUILDER       := podman

binaries: image _binaries

_binaries:
	rm -rf bin
	$(eval cid := $(shell $(BUILDER) create $(IMAGE)))
	$(BUILDER) cp $(cid):/opt/usernetes/bin ./bin
	$(BUILDER) rm $(cid)

image:
	$(BUILDER) build -t $(IMAGE) .

test: image _test

_test:
	./hack/smoketest-podman.sh u7s-test-crio $(IMAGE) --cri=crio

up: image _up

_up:
	$(BUILDER)-compose --project-name=usernetes up -d
	$(BUILDER) run --rm -v usernetes_tls-master:/a busybox timeout 60 sh -c "until test -f /a/done; do sleep 1; echo \"waiting for /a/done\"; done"
	mkdir -p $(HOME)/.config/usernetes
	$(BUILDER) run --rm -v usernetes_tls-master:/a busybox cat /a/admin.kubeconfig > $(HOME)/.config/usernetes/admin.kubeconfig
	sed -i s/master:6443/127.0.0.1:6443/g $(HOME)/.config/usernetes/admin.kubeconfig
	echo "To use kubectl: export KUBECONFIG=$(HOME)/.config/usernetes/admin.kubeconfig"

down:
	$(BUILDER)-compose --project-name=usernetes down -v -t 0
	rm -f $(HOME)/.config/usernetes/admin.kubeconfig

artifact: binaries _artifact

_artifact:
	rm -rf _artifact _SHA256SUMS
	mkdir _artifact
	( cd .. && tar --exclude=usernetes/.git --exclude=usernetes/_artifact -cjvf ./usernetes/_artifact/usernetes-x86_64.tbz usernetes )
	(cd _artifact ; sha256sum * > ../_SHA256SUMS; mv ../_SHA256SUMS ./SHA256SUMS)
	cat _artifact/SHA256SUMS

clean:
	rm -rf _artifact bin

.PHONY: binaries _binaries image test _test up _up down artifact _artifact clean
