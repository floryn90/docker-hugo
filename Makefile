PATH=$(shell pwd)/src/bin:$(shell echo $$PATH)

.PHONY: default build clean build-debug prepare test test-docsy test-docuapi push-edge push-release bump enable-qemu

default: clean prepare build

build:
	@make -f target/bundle/Makefile || (tail -50 target/bundle/build.log && exit 1)

clean:
	@rm -rf target

build-debug: src/bin/buildx
	@make -f target/bundle/Makefile DEBUG=true

prepare: src/bin/buildx
	@rm -rf target/bundle
	@docker run --rm -i -v $$(pwd):/work -u $$(id -u) \
		klakegg/docker-project-prepare:edge \
		-t target/bundle
	@sed -i "s:DOCKER_CLI_EXPERIMENTAL=enabled docker buildx:buildx:g" target/bundle/Makefile
#	@sed -i 's:--progress plain \\:--progress plain \\\n                --annotation $(DOCKER_METADATA_OUTPUT_ANNOTATIONS) \\:g' target/bundle/Makefile
	@sed -i "s:--push:--provenance=true --sbom=true --push:g" target/bundle/Makefile

test: test-docsy test-docuapi

test-docsy:
	@rm -rf target/test/docsy
	@git clone -b v0.11.0 https://github.com/google/docsy.git target/test/docsy
	@docker run --rm -i -v $$(pwd)/target/test/docsy:/src -u $$(id -u) --entrypoint npm floryn90/hugo:ext-alpine install
	@docker run --rm -i -v $$(pwd)/target/test/docsy:/src -u $$(id -u) floryn90/hugo:ext-alpine

test-docuapi:
	@rm -rf target/test/docuapi
	@git clone -b v2.4.0 https://github.com/bep/docuapi.git target/test/docuapi
	@docker run --rm -i -v $$(pwd)/target/test/docuapi:/src -u $$(id -u) --entrypoint npm floryn90/hugo:ext-alpine install
	@docker run --rm -i -v $$(pwd)/target/test/docuapi:/src -u $$(id -u) floryn90/hugo:ext-alpine

push-edge:
	@make -f target/bundle/Makefile push-edge

push-release:
	@make -f target/bundle/Makefile push-stable

bump:
	@RELEASE=$(version) bump

src/bin/buildx:
	@curl -sL -o src/bin/buildx https://github.com/docker/buildx/releases/latest/download/buildx-$(shell curl -s https://api.github.com/repos/docker/buildx/releases/latest | jq -r .tag_name).linux-amd64
	@chmod a+x src/bin/buildx
	@docker buildx create --use

enable-qemu:
	@sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
