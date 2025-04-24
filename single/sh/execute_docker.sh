#!/bin/bash
source ../../.env

echo "Dockerネットワーク・コンテナを停止・削除中..."
docker stop "$MYSQL_CONTAINER_LABEL" "$PHPMYADMIN_CONTAINER_LABEL" "$LOAD_BALANCER_CONTAINER_LABEL" redis
docker stop "$WEB_SERVER_CONTAINER_LABEL" "$WEB_SERVER_CONTAINER_LABEL"1 "$WEB_SERVER_CONTAINER_LABEL"2
docker stop "$APP_CONTAINER_LABEL"1 "$APP_CONTAINER_LABEL"2
docker rm "$MYSQL_CONTAINER_LABEL" "$PHPMYADMIN_CONTAINER_LABEL" "$LOAD_BALANCER_CONTAINER_LABEL" redis
docker rm "$WEB_SERVER_CONTAINER_LABEL" "$WEB_SERVER_CONTAINER_LABEL"1 "$WEB_SERVER_CONTAINER_LABEL"2
docker rm "$APP_CONTAINER_LABEL"1 "$APP_CONTAINER_LABEL"2
docker network rm "$NETWORK_LABEL"

docker volume prune -f

# --- ネットワークを作成 ---
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

# --- nginxコンテナ起動 ---
docker run -d \
  --name "$WEB_SERVER_CONTAINER_LABEL" \
  --network "$NETWORK_LABEL" \
  -p 8080:8080 \
  -p 443:443 \
  nginx:latest

docker run -d \
  --name redis \
  --network "$NETWORK_LABEL" \
  -p 6379:6379 \
  redis:latest
  
# --- opensslが入っているローカル環境でのみ以下を実行してserver.key,server.crtを作成 ---
# mkdir -p ../webserver/certs
# openssl req -x509 -nodes -days 365 \
#   -newkey rsa:2048 \
#   -keyout ../webserver/certs/server.key \
#   -out ../webserver/certs/server.crt \
#   -subj "/C=JP/ST=Tokyo/L=Shibuya/O=Example/OU=Dev/CN=localhost"

# --- ディレクトリ作成 ---
docker exec "$WEB_SERVER_CONTAINER_LABEL" mkdir -p /app /app/logs /etc/nginx/certs

# --- Java & MySQLクライアントインストール ---
docker exec "$WEB_SERVER_CONTAINER_LABEL" sh -c "apt update && apt install -y openjdk-17-jdk default-mysql-client"
docker exec "$WEB_SERVER_CONTAINER_LABEL" ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

echo "Docker環境構築完了。"

# --- アプリビルド ---
mvn clean install -f "$BACKEND_DIR_PATH/$BACKEND_PROJECT_NAME/pom.xml"
npm install --prefix "$FRONTEND_DIR_PATH/$FRONTEND_PROJECT_NAME"
(cd "$FRONTEND_DIR_PATH/$FRONTEND_PROJECT_NAME" && npm run build -- --configuration=docker)

# --- 成果物をコンテナにコピー ---
docker cp "$BACKEND_DIR_PATH/$BACKEND_PROJECT_NAME/target/$BACKEND_FILE_NAME" "$WEB_SERVER_CONTAINER_LABEL":/app/
docker cp "$FRONTEND_DIR_PATH/$FRONTEND_PROJECT_NAME/dist/$FRONTEND_PROJECT_NAME" "$WEB_SERVER_CONTAINER_LABEL":/usr/share/nginx/html
docker cp ../webserver/default.conf "$WEB_SERVER_CONTAINER_LABEL":/etc/nginx/conf.d/default.conf
docker cp ../webserver/certs/server.crt "$WEB_SERVER_CONTAINER_LABEL":/etc/nginx/certs/
docker cp ../webserver/certs/server.key "$WEB_SERVER_CONTAINER_LABEL":/etc/nginx/certs/

docker exec "$WEB_SERVER_CONTAINER_LABEL" nginx -s reload
docker restart "$WEB_SERVER_CONTAINER_LABEL"
docker exec "$WEB_SERVER_CONTAINER_LABEL" sh -c "nohup java -Dspring.profiles.active=docker -jar /app/${BACKEND_FILE_NAME}"
docker exec -it "$WEB_SERVER_CONTAINER_LABEL" sh -c "tail -n 100 -f /app/logs/application_info.log"
