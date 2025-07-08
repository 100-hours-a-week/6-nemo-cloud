#!/bin/bash

# === [ 사용자 정의 ] ===
DOCKER_CONTAINER_NAME="mysql-container"  # GCP Docker 컨테이너 이름
MYSQL_USER="root"
MYSQL_PASSWORD="your_mysql_password"
RDS_HOST="your-rds-endpoint.rds.amazonaws.com"
RDS_USER="prod"
RDS_PASSWORD="your_rds_password"

DUMP_FILE="dump.sql"

# === [ 1. Docker 컨테이너에서 덤프 ] ===
echo "[1/3] Docker 컨테이너에서 mysqldump 수행..."
docker exec -i "$DOCKER_CONTAINER_NAME" \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --all-databases > "$DUMP_FILE"

if [ $? -ne 0 ]; then
  echo "❌ mysqldump 실패. 비밀번호 확인 또는 컨테이너 상태 확인."
  exit 1
fi
echo "✅ dump.sql 생성 완료."

# === [ 2. RDS로 import ] ===
echo "[2/3] RDS에 데이터 import 시작..."
mysql -h "$RDS_HOST" -u"$RDS_USER" -p"$RDS_PASSWORD" < "$DUMP_FILE"

if [ $? -ne 0 ]; then
  echo "❌ RDS import 실패. 연결 문제 또는 권한 확인."
  exit 1
fi
echo "✅ RDS import 완료."

# === [ 3. 완료 후 정리 ] ===
echo "[3/3] 정리 중..."
rm -f "$DUMP_FILE"
echo "🎉 마이그레이션 완료."