FROM golang:1.22.2-alpine AS builder

RUN mkdir /app
COPY . /app
WORKDIR /app
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o broker-service ./cmd/api
RUN chmod +x broker-service

FROM alpine:latest
RUN mkdir /app
COPY --from=builder /app/broker-service /app/
CMD ["/app/broker-service"]