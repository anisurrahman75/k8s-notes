##STAGE : 1
FROM golang:latest as builder
LABEL maintainer="Anisur Rahman <sunny.cse7575@gmail.com>"
WORKDIR /app
COPY . .
RUN go mod download
##STAGE : 2
RUN CGO_ENABLED=0 go build -o web-server -a
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/web-server .
CMD ["./web-server"]
