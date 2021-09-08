.PHONY: %

LAST_TAG      = $(shell git describe --tags --abbrev=0 HEAD^)
COMMIT        = $(shell git rev-parse --short HEAD)
FULL_COMMIT   = $(shell git rev-parse HEAD)
RELEASE_NOTES = `git log ${LAST_TAG}..HEAD --oneline --decorate`
DATE          = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCKER_REPO   = yetio/v2ray-exporter

export DOCKER_CLI_EXPERIMENTAL=enabled

lint:
	golangci-lint run *.go

release_notes:
	@echo "${RELEASE_NOTES}"

before_build:
	go get github.com/mitchellh/gox

check_tag:
	test ! -z "${TAG}"

dev:
	skaffold dev --port-forward --no-prune=false

build: check_tag
	env GOMIPS=softfloat gox -verbose \
	    -output "dist/{{.Dir}}_{{.OS}}_{{.Arch}}" \
	    -osarch "linux/mipsle linux/amd64 linux/arm64 linux/arm darwin/amd64 windows/amd64" \
	    -ldflags "-X main.buildCommit=${COMMIT} \
	              -X main.buildDate=${DATE} \
	              -X main.buildVersion=${TAG}" \
	    ./...

release: build
	@ghr -u yetio -b "${RELEASE_NOTES}" -c "${FULL_COMMIT}" "${TAG}" dist/

docker_build: build
	docker build --build-arg ARCH=mipsel -t "${DOCKER_REPO}:${TAG}-mipsel" .
	docker build --build-arg ARCH=amd64 -t "${DOCKER_REPO}:${TAG}-amd64" .
	docker build --build-arg ARCH=arm64 -t "${DOCKER_REPO}:${TAG}-arm64" .
	docker build --build-arg ARCH=arm -t "${DOCKER_REPO}:${TAG}-arm" .

docker_push: check_tag
	docker push "${DOCKER_REPO}:${TAG}-amd64"
	docker push "${DOCKER_REPO}:${TAG}-mipsel"
	docker push "${DOCKER_REPO}:${TAG}-arm64"
	docker push "${DOCKER_REPO}:${TAG}-arm"

docker_manifest: check_tag
	docker manifest create --amend "${DOCKER_REPO}:${TAG}" "${DOCKER_REPO}:${TAG}-amd64" "${DOCKER_REPO}:${TAG}-arm64" "${DOCKER_REPO}:${TAG}-arm"
	docker manifest annotate "${DOCKER_REPO}:${TAG}" "${DOCKER_REPO}:${TAG}-arm64" --os linux --arch arm64
	docker manifest annotate "${DOCKER_REPO}:${TAG}" "${DOCKER_REPO}:${TAG}-arm" --os linux --arch arm
	docker manifest push --purge "${DOCKER_REPO}:${TAG}"
