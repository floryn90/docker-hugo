PATH := $(CURDIR)/src/bin:$(shell echo $$PATH)

.PHONY: default build clean build-debug prepare test test-docsy test-docuapi push-edge push-release bump enable-qemu

default: clean prepare build

build:
	@$(MAKE) -f target/bundle/Makefile || (tail -50 target/bundle/build.log && exit 1)

clean:
	@$(RM) -rf target

build-debug: src/bin/buildx
	@$(MAKE) -f target/bundle/Makefile DEBUG=true

prepare: src/bin/buildx
	@$(RM) -rf target/bundle
	@$(DOCKER) run --rm -i -v $(CURDIR):/work -u $$(id -u) \
		klakegg/docker-project-prepare:edge \
		-t target/bundle
	@$(SED) -i "s:DOCKER_CLI_EXPERIMENTAL=enabled docker buildx:buildx:g" target/bundle/Makefile
#	@$(SED) -i 's:--progress plain \\:--progress plain \\\n                --annotation $(DOCKER_METADATA_OUTPUT_ANNOTATIONS) \\:g' target/bundle/Makefile
	@$(SED) -i "s:--push:--provenance=true --sbom=true --push:g" target/bundle/Makefile

test: test-docsy test-docuapi

test-docsy:
	@$(RM) -rf target/test/docsy
	@git clone -b v0.11.0 https://github.com/google/docsy.git target/test/docsy
	@$(DOCKER) run --rm -i -v $(CURDIR)/target/test/docsy:/src -u $$(id -u) --entrypoint npm floryn90/hugo:ext-alpine install
	@$(DOCKER) run --rm -i -v $(CURDIR)/target/test/docsy:/src -u $$(id -u) floryn90/hugo:ext-alpine

test-docuapi:
	@$(RM) -rf target/test/docuapi
	@git clone -b v2.4.0 https://github.com/bep/docuapi.git target/test/docuapi
	@$(DOCKER) run --rm -i -v $(CURDIR)/target/test/docuapi:/src -u $$(id -u) --entrypoint npm floryn90/hugo:ext-alpine install
	@$(DOCKER) run --rm -i -v $(CURDIR)/target/test/docuapi:/src -u $$(id -u) floryn90/hugo:ext-alpine

push-edge:
	@$(MAKE) -f target/bundle/Makefile push-edge

push-release:
	@$(MAKE) -f target/bundle/Makefile push-stable

bump:
	@RELEASE=$(version) bump

src/bin/buildx:
	@wget -q -O src/bin/buildx https://github.com/docker/buildx/releases/latest/download/buildx-$(shell wget -qO- https://api.github.com/repos/docker/buildx/releases/latest | grep -Po '"tag_name": "\K.*?(?=")').linux-amd64
	@chmod a+x src/bin/buildx
	@docker buildx create --use

enable-qemu:
	@sudo $(DOCKER) run --rm --privileged multiarch/qemu-user-static --reset -p yes
