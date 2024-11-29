# build frontend
FROM node:12.18.3-alpine3.12 AS frontend-builder
WORKDIR /app
COPY frontend /app
RUN export NODE_TLS_REJECT_UNAUTHORIZED=0 && \
  yarn config set "strict-ssl" false -g && \
  yarn config set registry https://registry.npmjs.org/ && \
  yarn install
RUN yarn build

# build backend
FROM golang:1.16.4-alpine AS backend-builder

# RUN echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.12/main" > /etc/apk/repositories
RUN apk add --no-cache build-base git musl-dev gcc

COPY models /src/godnslog/models
COPY server /src/godnslog/server
COPY cache /src/godnslog/cache
COPY *.go go.mod /src/godnslog/
WORKDIR /src/godnslog
RUN go mod tidy && \
  CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /go/bin/godnslog

# build app
FROM alpine:3.13.5

RUN apk add --no-cache -U tzdata ca-certificates libcap && \
	update-ca-certificates

RUN mkdir -p /app

COPY --from=backend-builder /go/bin/godnslog /app/godnslog
COPY --from=frontend-builder /app/dist /app/dist

ARG UID=1000
ARG GID=1000

RUN addgroup -g $GID -S app && adduser -u $UID -S -g app app && \
  chown -R app:app /app && \
  setcap cap_net_bind_service=eip /app/godnslog

WORKDIR /app
USER app

EXPOSE 8080
EXPOSE 53/UDP 53/TCP

ENTRYPOINT [ "/app/godnslog" ]
