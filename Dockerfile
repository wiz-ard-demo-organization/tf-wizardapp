# Multi-stage build: Stage 1 - Build the Go application
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
# Build static binary for Linux (no CGO dependencies)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky

# Multi-stage build: Stage 2 - Create minimal production image
FROM alpine:3.17.0 as release

WORKDIR /app
# Copy the compiled binary from build stage
COPY --from=build  /go/src/tasky/tasky .
# Copy web assets (HTML, CSS, JS files)
COPY --from=build  /go/src/tasky/assets ./assets
# Copy the Wiz exercise validation file (required for technical exercise)
COPY --from=build  /go/src/tasky/wizexercise.txt ./wizexercise.txt
EXPOSE 8080
ENTRYPOINT ["/app/tasky"]


