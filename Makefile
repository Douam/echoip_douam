DOCKER ?= docker
DOCKER_IMAGE ?= douam/echoip_douam
GEOIP_LICENSE_KEY = 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

OS := $(shell uname)
ifeq ($(OS),Linux)
	TAR_OPTS := --wildcards
endif
XGOARCH := amd64
XGOOS := linux
XBIN := $(XGOOS)_$(XGOARCH)/echoip_douam

DATA_DIR := data_db

all: lint test install

test:
	go test ./...

vet:
	go vet ./...

check-fmt:
	bash -c "diff --line-format='%L' <(echo -n) <(gofmt -d -s .)"

lint: check-fmt vet

install:
	go install ./...

databases := GeoLite2-City GeoLite2-Country GeoLite2-ASN

$(databases):
ifndef GEOIP_LICENSE_KEY
	$(error GEOIP_LICENSE_KEY must be set. Please see https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/)
endif
	mkdir -p $(DATA_DIR)
	@curl -fsSL -m 30 "https://download.maxmind.com/app/geoip_download?edition_id=$@&license_key=$(GEOIP_LICENSE_KEY)&suffix=tar.gz" | tar $(TAR_OPTS) --strip-components=1 -C $(DATA_DIR) -xzf - '*.mmdb'
	test ! -f $(DATA_DIR)/GeoLite2-City.mmdb || mv $(DATA_DIR)/GeoLite2-City.mmdb $(DATA_DIR)/city.mmdb
	test ! -f $(DATA_DIR)/GeoLite2-Country.mmdb || mv $(DATA_DIR)/GeoLite2-Country.mmdb $(DATA_DIR)/country.mmdb
	test ! -f $(DATA_DIR)/GeoLite2-ASN.mmdb || mv $(DATA_DIR)/GeoLite2-ASN.mmdb $(DATA_DIR)/asn.mmdb


geoip-download: $(databases)

# Create an environment to build multiarch containers (https://github.com/docker/buildx/)
docker-multiarch-builder:
	DOCKER_BUILDKIT=1 $(DOCKER) build -o . git://github.com/docker/buildx
	mkdir -p ~/.docker/cli-plugins
	mv buildx ~/.docker/cli-plugins/docker-buildx
	$(DOCKER) buildx create --name multiarch-builder --node multiarch-builder --driver docker-container --use
	$(DOCKER) run --rm --privileged multiarch/qemu-user-static --reset -p yes

docker-build: xinstall
	CGO_ENABLED=0 GOOS=linux go build -o $(XBIN) ./cmd/echoip_douam
	$(DOCKER) build -t $(DOCKER_IMAGE) .

docker-login:
	@echo "$(DOCKER_PASSWORD)" | $(DOCKER) login -u "$(DOCKER_USERNAME)" --password-stdin

docker-test:
	$(eval CONTAINER=$(shell $(DOCKER) run --rm --detach --publish-all $(DOCKER_IMAGE)))
	$(eval DOCKER_PORT=$(shell $(DOCKER) port $(CONTAINER) | cut -d ":" -f 2))
	curl -fsS -m 5 localhost:$(DOCKER_PORT) > /dev/null; $(DOCKER) stop $(CONTAINER)

docker-push: docker-test docker-login
	$(DOCKER) push $(DOCKER_IMAGE)

docker-pushx: docker-multiarch-builder docker-test docker-login
	$(DOCKER) buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t $(DOCKER_IMAGE) --push .

xinstall:
	env GOOS=$(XGOOS) GOARCH=$(XGOARCH) go install ./...

publish:
ifndef DEST_PATH
	$(error DEST_PATH must be set when publishing)
endif
	rsync -a $(GOPATH)/bin/$(XBIN) $(DEST_PATH)/$(XBIN)
	@sha256sum $(GOPATH)/bin/$(XBIN) > $(DEST_PATH)/$(XBIN)/checksums.txt

run:
	go run cmd/echoip_douam/main.go -a data_db/asn.mmdb -c data_db/city.mmdb -f data_db/country.mmdb -H x-forwarded-for -r -s -p
