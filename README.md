提示された `docker-compose.yml` に基づいて、すぐに使える構成の **README.md** を作成しました。

このREADMEは、プロジェクトの概要、セットアップ手順、環境変数の説明、そして重要な **Caddyの設定（Caddyfile）** までを網羅しています。

---

# n8n Production Stack with Auth Manager & Caddy

このリポジトリは、ワークフロー自動化ツール **n8n** をセキュアな本番環境で運用するための Docker Compose 構成です。
PostgreSQL によるデータ永続化、Caddy による SSL 自動化（HTTPS）、および外部 API 連携用のカスタム認証マネージャー（Auth Manager）を含んでいます。

## 🏗 アーキテクチャ構成

| サービス | 役割 | 内部ポート |
| --- | --- | --- |
| **n8n** | ワークフロー自動化エンジン | `5678` |
| **PostgreSQL** | n8n の設定・実行履歴データの永続化 (v16) | `5432` |
| **Auth Manager** | Yahoo! / Next Engine 等の OAuth トークン管理・更新 | `8000` |
| **Caddy** | リバースプロキシ、自動 SSL 証明書発行・更新 | `80`, `443` |

---

## 🚀 セットアップ手順

### 1. ディレクトリ構成の準備

以下のディレクトリ構造になるようにファイルとフォルダを準備します。

```
.
├── docker-compose.yml
├── .env
├── Caddyfile
├── volumes/
│   ├── pg_data/          # DBデータ用（自動生成）
│   └── n8n_data/         # n8nデータ用（自動生成）
└── auth-manager/
    ├── volumes/
    │   └── auth_manager_data/
    └── keys/
        └── yahoo_api_public.key  # Yahoo API用公開鍵

```

### 2. 環境変数の設定 (.env)

`.env` ファイルを作成し、以下の変数を設定してください。

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

Caddy がリバースプロキシとして機能し、n8n と Auth Manager へトラフィックを振り分けるための設定ファイル `Caddyfile` を作成します。

```caddyfile
{
    # メールアドレスを設定しておくと、SSL証明書期限切れ等の通知が届きます（任意）
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

### 4. docker-compose.yml の補足修正

`caddy` サービスが `Caddyfile` を読み込み、外部ポート（80/443）を開放するように、`docker-compose.yml` の `caddy` 部分を以下のように記述・確認してください。

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

※ また、ファイルの末尾にボリューム定義を追加してください：

```yaml
volumes:
  caddy_data:
  caddy_config:

```

### 5. 起動

コンテナをビルド・起動します。

```bash
docker-compose up -d

```

---

## ✅ 動作確認

起動後、ブラウザで以下のURLにアクセスして確認します。

1. **n8n**: `https://your-domain.com/`
* Basic認証（設定した場合）を経て、n8nのエディタ画面が表示されること。


2. **Auth Manager**: `https://your-domain.com/auth-manager/`
* Auth Manager のヘルスチェック応答やUIが表示されること。



---

## 🛠 メンテナンス

### ログの確認

```bash
docker-compose logs -f
# 特定のサービスのみ
docker-compose logs -f n8n

```

### データのバックアップ

`volumes/pg_data` と `volumes/n8n_data` ディレクトリを定期的にバックアップすることを推奨します。

---

## ⚠️ 注意事項
* **認証情報**: `.env` ファイルには API キーやパスワードが含まれるため、Git リポジトリにはコミットしないでください（`.gitignore` に追加推奨）。
