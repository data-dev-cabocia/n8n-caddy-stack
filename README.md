# n8n Production Stack on Xserver VPS

このリポジトリは、Xserver VPS 上でワークフロー自動化ツール **n8n** を運用するための Docker Compose 構成です。
Caddy による SSL 自動化（HTTPS）と、外部 API 連携（Yahoo!ショッピング/ネクストエンジン）用のカスタム認証マネージャー（Auth Manager）を統合しています。

## 🏗 アーキテクチャ構成

| サービス | 役割 | 内部ポート |
| --- | --- | --- |
| **n8n** | ワークフロー自動化エンジン | `5678` |
| **PostgreSQL** | n8n の設定・実行履歴データの永続化 (v16) | `5432` |
| **Auth Manager** | Yahoo! / Next Engine 等の OAuth トークン管理 | `8000` |
| **Caddy** | リバースプロキシ、自動 SSL、セキュリティヘッダー付与 | `80`, `443` |

---

## 🛡 Xserver VPS 事前設定

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

リポジトリ（または作業ディレクトリ）は以下の構造であることを前提としています。

```text
.
├── docker-compose.yml
├── .env
├── caddy/
│   └── Caddyfile             # Caddy設定ファイル
├── auth-manager/
│   ├── keys/
│   │   └── yahoo_api_public.key  # 事前に配置が必要
│   └── volumes/
│       └── auth_manager_data/    # 自動生成
└── volumes/                  # データ永続化（自動生成）
    ├── n8n_data/
    ├── pg_data/
    ├── caddy_data/
    └── caddy_config/

```

### 2. 環境変数の設定 (.env)

`.env` ファイルを作成し、以下の項目を設定してください。

```ini
# --- General ---
DOMAIN=n8n.japancaviar.jp
ACME_EMAIL=your-email@example.com
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
N8N_HOST=n8n.japancaviar.jp
N8N_PORT=5678
N8N_PROTOCOL=https

# --- Auth Manager (Yahoo / NextEngine) ---
YAHOO_CLIENT_ID=your_yahoo_client_id
YAHOO_CLIENT_SECRET=your_yahoo_secret
YAHOO_REDIRECT_URI=https://n8n.japancaviar.jp/auth-manager/yahoo/callback
NEXTENGINE_CLIENT_ID=your_ne_id
NEXTENGINE_CLIENT_SECRET=your_ne_secret
NEXTENGINE_REDIRECT_URI=https://n8n.japancaviar.jp/auth-manager/nextengine/callback

# --- Auth Manager Integration ---
N8N_API_BASE=http://n8n:5678
N8N_API_TOKEN=your_n8n_api_key_created_in_ui
STORE_SELLER_ID=your_store_id
STORE_PUBLIC_KEY_PATH=/app/keys/yahoo_api_public.key
STORE_KEY_VERSION=1
ROOT_PATH=/auth-manager

```

### 3. Caddyfile の配置

`caddy/Caddyfile` を以下の内容で作成します。

```caddyfile
{
    email {$ACME_EMAIL}
}

{$DOMAIN} {
    encode gzip
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "no-referrer-when-downgrade"
    }

    # Auth Manager へのルーティング
    handle /auth-manager* {
        uri strip_prefix /auth-manager
        reverse_proxy auth-manager:8000
    }

    # n8n へのルーティング
    reverse_proxy n8n:5678
}

```

### 4. 起動

コンテナをバックグラウンドで起動します。

```bash
docker-compose up -d

```

---

## ✅ 動作確認

起動後、数秒〜1分程度でSSL証明書が自動発行されます。ブラウザでアクセスして確認します。

1. **n8n**: `https://n8n.japancaviar.jp/`
* Basic認証（設定時）を経てエディタが表示されること。


2. **Auth Manager**: `https://n8n.japancaviar.jp/auth-manager/`
* Auth Manager のUIまたはレスポンスが表示されること。



---

## 🛠 メンテナンス

### ログの確認

```bash
# 全体のログ
docker-compose logs -f

# 特定サービスのログ（例：n8n）
docker-compose logs -f n8n

```

### コンテナの再起動（設定変更時など）

```bash
docker-compose restart caddy

```

### データのバックアップ

以下のディレクトリが永続化データの本体です。定期的なバックアップを推奨します。

* `./volumes/pg_data` (データベース)
* `./volumes/n8n_data` (n8nワークフロー定義など)
* `./auth-manager/volumes/auth_manager_data` (トークンDB)

---

## ⚠️ 注意事項

* **セキュリティ**: `.env` ファイルには API キーやパスワードが含まれるため、Git リポジトリにはコミットしないでください（`.gitignore` に追加してください）。
* **PostgreSQL**: ポート `5432` は `127.0.0.1` にバインドされており、外部からはアクセスできません（SSHトンネル経由などで接続可能です）。
