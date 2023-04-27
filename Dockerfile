FROM golang:1.16-alpine AS backend
WORKDIR /go/src/cloudshell
COPY ./cmd ./cmd
COPY ./internal ./internal
COPY ./pkg ./pkg
COPY ./go.mod .
COPY ./go.sum .
ENV CGO_ENABLED=0
RUN go mod vendor
ARG VERSION_INFO=dev-build
RUN go build -a -v \
  -ldflags " \
  -s -w \
  -extldflags 'static' \
  -X main.VersionInfo='${VERSION_INFO}' \
  " \
  -o ./bin/cloudshell \
  ./cmd/cloudshell

FROM node:16.0.0-alpine AS frontend
WORKDIR /app
COPY ./package.json .
COPY ./package-lock.json .
RUN npm install

FROM alpine:3.14.0
WORKDIR /app
RUN apk update && apk add --no-cache bash ncurses openvpn openssh iproute2 nano
COPY --from=backend /go/src/cloudshell/bin/cloudshell /app/cloudshell
COPY --from=frontend /app/node_modules /app/node_modules
COPY ./public /app/public

COPY ./run/* /etc/local.d/
RUN chmod +x /etc/local.d/openvpn.start

RUN \
  # Install required packages
  echo "http://dl-3.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  apk --update --upgrade add \
  bash \
  fluxbox \
  git \
  supervisor \
  xvfb \
  x11vnc \
  && \
  # Install noVNC
  git clone --depth 1 https://github.com/novnc/noVNC.git /root/noVNC && \
  git clone --depth 1 https://github.com/novnc/websockify /root/noVNC/utils/websockify && \
  rm -rf /root/noVNC/.git && \
  rm -rf /root/noVNC/utils/websockify/.git

RUN ln -s /app/cloudshell /usr/bin/cloudshell

RUN adduser -D -u 1000 user
RUN mkdir -p /home/user
RUN chown user:user /app -R
WORKDIR /
ENV WORKDIR=/app
COPY ./run/* /home/user

RUN chown -R user:user /etc/openvpn

RUN echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/ipv4.conf
RUN sysctl -p /etc/sysctl.d/ipv4.conf

# USER user
ENTRYPOINT ["/app/cloudshell"]
