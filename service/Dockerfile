FROM golang:1.13-alpine as builder
RUN apk update && apk upgrade && apk add --no-cache bash git make gcc musl-dev
WORKDIR /go/src/github.com/malike/secrets-store-csi-driver-poc/
COPY . .
RUN make build-service

FROM alpine
COPY --from=builder /go/src/github.com/malike/secrets-store-csi-driver-poc/service/goservice ./
ENTRYPOINT ["./goservice"]