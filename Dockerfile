# Build with latest Go version
FROM golang:latest AS build

# 
WORKDIR /go/src/github.com/Douam/echoip_douam
COPY . .

# Must build without cgo because libc is unavailable in runtime image
ENV GO111MODULE=on CGO_ENABLED=0
RUN make

# Run
FROM alpine:latest
EXPOSE 8080

#COPY --from=build /go/cmd/echoip /opt/echoip
#COPY --from=build /go/src/github.com/Douam/echoip_douam/echoip_douam /opt/echoip_douam/
#COPY html /opt/echoip_douam/html

COPY --from=build /go/src/github.com/Douam/echoip_douam /opt/echoip_douam
COPY html /opt/echoip_douam/html

WORKDIR /opt/echoip_douam
ENTRYPOINT ["/opt/echoip_douam/echoip"]
