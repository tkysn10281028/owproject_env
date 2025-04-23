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

# --- ネットワークを作成 ---
echo "Dockerネットワーク・コンテナ作成中..."
docker network create "$NETWORK_LABEL"

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

mvn clean install -f "$BACKEND_DIR_PATH/$BACKEND_PROJECT_NAME/pom.xml"
npm install --prefix "$FRONTEND_DIR_PATH/$FRONTEND_PROJECT_NAME"
(cd "$FRONTEND_DIR_PATH/$FRONTEND_PROJECT_NAME" && npm run build -- --configuration=docker)

# Applicationサーバーを起動
for i in 1 2; do
  docker run -d \
    --name "${APP_CONTAINER_LABEL}$i" \
    --network "$NETWORK_LABEL" \
    openjdk:17-jdk sleep infinity

  docker exec "$APP_CONTAINER_LABEL"$i mkdir -p /app /app/logs
  docker exec "$APP_CONTAINER_LABEL"$i ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
  docker cp "$BACKEND_DIR_PATH/$BACKEND_PROJECT_NAME/target/$BACKEND_FILE_NAME" "$APP_CONTAINER_LABEL"$i:/app/
  docker exec "$APP_CONTAINER_LABEL"$i sh -c "nohup java -Dspring.profiles.active=docker -jar /app/${BACKEND_FILE_NAME} > /dev/null 2>&1 &"
done

# Webサーバーを起動
for i in 1 2; do
  docker run -d \
    --name "$WEB_SERVER_CONTAINER_LABEL"$i \
    --network $NETWORK_LABEL \
    -p 844$i:80 \
   nginx:latest

  docker cp "$FRONTEND_DIR_PATH/$FRONTEND_PROJECT_NAME/dist/$FRONTEND_PROJECT_NAME" "$WEB_SERVER_CONTAINER_LABEL"$i:/usr/share/nginx/html
  docker cp ../webserver/default.conf "$WEB_SERVER_CONTAINER_LABEL"$i:/etc/nginx/conf.d/default.conf

  docker exec "$WEB_SERVER_CONTAINER_LABEL"$i nginx -s reload
  docker restart "$WEB_SERVER_CONTAINER_LABEL"$i
done

# --- opensslが入っているローカル環境でのみ以下を実行してserver.key,server.crtを作成 ---
# mkdir -p ../webserver/certs
# openssl req -x509 -nodes -days 365 \
#   -newkey rsa:2048 \
#   -keyout ../webserver/certs/server.key \
#   -out ../webserver/certs/server.crt \
#   -subj "/C=JP/ST=Tokyo/L=Shibuya/O=Example/OU=Dev/CN=localhost"

docker run -d \
  --name "$LOAD_BALANCER_CONTAINER_LABEL" \
  --network $NETWORK_LABEL \
  -p 443:443 -p 80:80 \
  nginx:latest

docker exec "$LOAD_BALANCER_CONTAINER_LABEL" mkdir -p /etc/nginx/certs
docker cp ../webserver/certs/server.crt "$LOAD_BALANCER_CONTAINER_LABEL":/etc/nginx/certs/
docker cp ../webserver/certs/server.key "$LOAD_BALANCER_CONTAINER_LABEL":/etc/nginx/certs/
docker cp ../webserver/nginx.conf "$LOAD_BALANCER_CONTAINER_LABEL":/etc/nginx/nginx.conf

docker exec "$LOAD_BALANCER_CONTAINER_LABEL" nginx -s reload
docker restart "$LOAD_BALANCER_CONTAINER_LABEL"

docker exec -it "$APP_CONTAINER_LABEL"1 sh -c "tail -n 100 -f /app/logs/application_info.log"