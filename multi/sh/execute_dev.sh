#!/bin/bash
source ../../.env

echo "Dockerネットワーク・コンテナを停止・削除中..."
docker stop "$MYSQL_CONTAINER_LABEL" "$PHPMYADMIN_CONTAINER_LABEL" "$LOAD_BALANCER_CONTAINER_LABEL" redis
docker stop "$WEB_SERVER_CONTAINER_LABEL"1 "$WEB_SERVER_CONTAINER_LABEL"2
docker stop "$APP_CONTAINER_LABEL"1 "$APP_CONTAINER_LABEL"2
docker rm "$MYSQL_CONTAINER_LABEL" "$PHPMYADMIN_CONTAINER_LABEL" "$LOAD_BALANCER_CONTAINER_LABEL" redis
docker rm "$WEB_SERVER_CONTAINER_LABEL"1 "$WEB_SERVER_CONTAINER_LABEL"2
docker rm "$APP_CONTAINER_LABEL"1 "$APP_CONTAINER_LABEL"2
docker network rm "$NETWORK_LABEL"

docker volume prune -f

echo "Dockerネットワーク・コンテナ作成中..."
docker network create "$NETWORK_LABEL"

# MySQLコンテナ起動
docker run -d \
  --name "$MYSQL_CONTAINER_LABEL" \
  --network "$NETWORK_LABEL" \
  -e TZ=Asia/Tokyo \
  -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  -e MYSQL_DATABASE="$MYSQL_DATABASE" \
  -e MYSQL_USER="$MYSQL_USER" \
  -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
  -p 3306:3306 \
  mysql:latest

# phpMyAdminコンテナ起動
docker run -d \
  --name "$PHPMYADMIN_CONTAINER_LABEL" \
  --network "$NETWORK_LABEL" \
  -e PMA_HOST="$MYSQL_CONTAINER_LABEL" \
  -e PMA_PORT="3306" \
  -p 8082:80 \
  --platform=linux/arm64 \
  arm64v8/phpmyadmin:latest

docker run -d \
  --name redis \
  --network "$NETWORK_LABEL" \
  -p 6379:6379 \
  redis:latest