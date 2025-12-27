#!/bin/bash

# エラーが発生したら即座に停止
set -e

# --- 設定項目 ---
# docker-composeで定義しているサービス名
SERVICE_NAME="n8n"
# バックアップ対象のディレクトリ（docker-compose.ymlからの相対パス）
DATA_DIR="./volumes/n8n_data"
# バックアップ保存先
BACKUP_DIR="./backups"
# 日付フォーマット
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "=========================================="
echo " Starting n8n Update Process"
echo " Date: $(date)"
echo "=========================================="

# 1. バックアップの作成
if [ -d "$DATA_DIR" ]; then
    echo "[1/4] Backing up data..."
    mkdir -p "$BACKUP_DIR"
    # tarコマンドでアーカイブを作成（容量節約のため圧縮）
    tar -czf "${BACKUP_DIR}/n8n_data_${TIMESTAMP}.tar.gz" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
    echo "      Backup created: ${BACKUP_DIR}/n8n_data_${TIMESTAMP}.tar.gz"
else
    echo "[Warning] Data directory not found. Skipping backup."
fi

# 2. 最新イメージのプル
echo "[2/4] Pulling latest image..."
docker compose pull "$SERVICE_NAME"

# 3. コンテナの再構築（Update）
echo "[3/4] Recreating container..."
docker compose up -d "$SERVICE_NAME"

# 4. 古いイメージの削除（任意：ディスク節約）
echo "[4/4] Cleaning up old images..."
docker image prune -f

echo "=========================================="
echo " Update Completed Successfully!"
echo " Checking logs (Press Ctrl+C to exit)..."
echo "=========================================="

# ログを表示して正常起動を確認
docker compose logs -f "$SERVICE_NAME"
