# ============================================================
# Stage 1: Build picoclaw with WhatsApp native support
# ============================================================
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git make gcc musl-dev

WORKDIR /src

# Cache dependencies
COPY go.mod go.sum ./
RUN CGO_ENABLED=0 go mod download

# Copy source, generate embedded workspace, then build
COPY . .
RUN CGO_ENABLED=0 go generate ./... && \
    mkdir -p build && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
      -tags whatsapp_native \
      -ldflags "-s -w" \
      -o build/picoclaw \
      ./cmd/picoclaw

# ============================================================
# Stage 2: Runtime image with tools for full-stack development
# ============================================================
FROM alpine:3.21

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    bash \
    git \
    docker-cli \
    nodejs \
    npm \
    python3

# Copy picoclaw binary
COPY --from=builder /src/build/picoclaw /usr/local/bin/picoclaw

# Copy workspace (skills, identity, etc.)
COPY workspace/ /root/.picoclaw/workspace/

# Copy config
COPY config.json /root/.picoclaw/config.json

WORKDIR /root/.picoclaw

# Create dev workspace directory
RUN mkdir -p /root/ws/ai-space/ai-engineer

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -q --spider http://localhost:18790/health || exit 1

ENTRYPOINT ["picoclaw"]
CMD ["gateway"]
