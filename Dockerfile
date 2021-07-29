FROM golang:alpine AS builder

RUN apk --update add git && \
    rm -rf /var/lib/apt/lists/* && \
    rm /var/cache/apk/*

ARG GITHUB_TOKEN
RUN [ -z "$GITHUB_TOKEN" ] && echo "GITHUB_TOKEN build-arg is required" && exit 1 || true
RUN git config --global url."https://${GITHUB_TOKEN}:x-oauth-basic@github.com/".insteadOf "https://github.com/"

RUN git clone https://github.com/riptano/cloud-gate.git

WORKDIR ./cloud-gate
RUN git fetch origin && git checkout HEAD

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# download dependency using go mod
RUN go mod download

# Build the application
RUN go build -o main ./proxy

FROM alpine

COPY --from=builder /go/cloud-gate/main /

ENV PROXY_QUERY_ADDRESS="0.0.0.0"
ENV PROXY_METRICS_ADDRESS="0.0.0.0"

# Command to run
ENTRYPOINT ["/main"]

