# n8n Production Stack on Xserver VPS

このリポジトリは、Xserver VPS 上でワークフロー自動化ツール **n8n** を運用するための Docker Compose 構成です。
Caddy による SSL 自動化（HTTPS）と、外部 API 連携用のカスタム認証マネージャー（Auth Manager）を含んでいます。

## 🏗 アーキテクチャ構成

| サービス | 役割 | 内部ポート |
| --- | --- | --- |
| **n8n** | ワークフロー自動化エンジン | `5678` |
| **PostgreSQL** | n8n の設定・実行履歴データの永続化 (v16) | `5432` |
| **Auth Manager** | Yahoo! / Next Engine 等の OAuth トークン管理 | `8000` |
| **Caddy** | リバースプロキシ、自動 SSL 証明書発行・更新 | `80`, `443` |

---

## 🛡 Xserver VPS ポート開放設定

本番運用を開始する前に、Xserver VPS の管理パネルと OS の両方でポート（80番, 443番）を許可する必要があります。

### 1. VPS管理パネル（パケットフィルタ）の設定

1. **Xserver VPS 管理コンソール** にログインします。
2. 対象サーバーの **「パケットフィルタ設定」** をクリックします。
3. 以下のポートが「許可」になっているか確認し、なっていなければ設定を追加・変更してください。
* **Web (80)**: 許可 (TCP)
* **SSL (443)**: 許可 (TCP)
* *SSH (22)*: 許可 (作業用)



### 2. OS側のファイアウォール設定 (Ubuntuの場合)

サーバーにSSH接続し、`ufw` コマンドで HTTP/HTTPS 通信を許可します。

```bash
# ポート80と443を許可
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 設定の再読み込み
sudo ufw reload

# ステータスの確認（Status: active で 80/443 が ALLOW になっていること）
sudo ufw status

```

---

## 🚀 セットアップ手順

### 1. ディレクトリ構成の準備

サーバー上で以下のディレクトリ構造になるように準備します。

```
.
├── docker-compose.yml
├── .env
├── Caddyfile
├── volumes/
│   ├── pg_data/          # DBデータ用
│   └── n8n_data/         # n8nデータ用
└── auth-manager/
    ├── volumes/
    │   └── auth_manager_data/
    └── keys/
        └── yahoo_api_public.key  # Yahoo API用公開鍵

```

### 2. 環境変数の設定 (.env)

`.env` ファイルを作成し、自身のドメインや認証情報を設定してください。

```ini
# --- General ---
DOMAIN=your-domain.com
TZ=Asia/Tokyo

# --- PostgreSQL ---
POSTGRES_DB=n8n
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=secure_db_password
POSTGRES_PORT=5432

# --- n8n ---
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=secure_n8n_password
N8N_HOST=your-domain.com
N8N_PORT=5678
N8N_PROTOCOL=https

# --- Auth Manager (Yahoo / NextEngine) ---
YAHOO_CLIENT_ID=your_yahoo_client_id
YAHOO_CLIENT_SECRET=your_yahoo_secret
YAHOO_REDIRECT_URI=https://your-domain.com/auth-manager/yahoo/callback
NEXTENGINE_CLIENT_ID=your_ne_id
NEXTENGINE_CLIENT_SECRET=your_ne_secret
NEXTENGINE_REDIRECT_URI=https://your-domain.com/auth-manager/nextengine/callback

# --- Auth Manager Integration ---
N8N_API_BASE=http://n8n:5678
N8N_API_TOKEN=your_n8n_api_key_created_in_ui
STORE_SELLER_ID=your_store_id
STORE_PUBLIC_KEY_PATH=/app/keys/yahoo_api_public.key
STORE_KEY_VERSION=1
ROOT_PATH=/auth-manager

```

### 3. Caddyfile の作成

リバースプロキシ設定ファイル `Caddyfile` を作成します。これにより SSL が自動適用されます。

```caddyfile
{
    # SSL証明書期限切れ等の通知用メールアドレス（任意）
    # email your-email@example.com
}

{$DOMAIN} {
    # Auth Manager へのルーティング
    handle_path /auth-manager* {
        reverse_proxy auth-manager:8000
    }

    # n8n へのルーティング (デフォルト)
    handle {
        reverse_proxy n8n:5678
    }
}

```

### 4. docker-compose.yml の確認

`caddy` サービスが外部ポートを開放し、設定ファイルを読み込むようになっているか確認してください。

```yaml
  caddy:
    image: caddy:2
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n
      - auth-manager

```

*(末尾の volumes 定義に `caddy_data`, `caddy_config` も必要です)*

### 5. 起動

```bash
docker-compose up -d

```

---

## ✅ 動作確認

ブラウザでアクセスして確認します。

1. **n8n**: `https://your-domain.com/`
2. **Auth Manager**: `https://your-domain.com/auth-manager/`

---

## 🛠 メンテナンス

### ログの確認

```bash
docker-compose logs -f

```

### データのバックアップ

`volumes/pg_data` と `volumes/n8n_data` ディレクトリを定期的にバックアップすることを推奨します。

---

## ⚠️ 注意事項

* **認証情報**: `.env` ファイルには API キーやパスワードが含まれるため、Git リポジトリにはコミットしないでください（`.gitignore` に追加推奨）。
