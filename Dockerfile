# Build
FROM golang:1.15-buster AS build
WORKDIR /go/src/github.com/mpolden/echoip_douam
COPY . .

# Must build without cgo because libc is unavailable in runtime image
ENV GO111MODULE=on CGO_ENABLED=0
RUN make

# Run
FROM scratch
EXPOSE 8080

COPY --from=build /go/bin/echoip_douam /opt/echoip_douam/
COPY html /opt/echoip_douam/html

WORKDIR /opt/echoip_douam
ENTRYPOINT ["/opt/echoip/echoip_douam"]
