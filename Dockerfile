# Build with latest Go version
FROM golang:latest AS build

WORKDIR /go/src/github.com/Douam/echoip_douam
COPY . .

# Must build without cgo because libc is unavailable in runtime image
ENV GO111MODULE=on CGO_ENABLED=0
RUN make xinstall

# Run
FROM scratch
EXPOSE 8080

COPY --from=build /go/src/github.com/Douam/echoip_douam/html /opt/echoip_douam/html
COPY --from=build /go/bin/echoip_douam /opt/echoip_douam/

WORKDIR /opt/echoip_douam
ENTRYPOINT ["/opt/echoip_douam/echoip_douam"]
