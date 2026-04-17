# FightHub（仮）



## 概要（What）
FightHubは、距離を超えてトレーナーからアドバイスを受けられる
ボクシングのプラットフォームです。

会員がリクエストを投稿し、トレーナーがアドバイスを返すことで、
新しいボクシングの学び方を提供します。


## 背景（Why）
息子がボクシングを習っていますが、
距離や時間の問題により、指導を受けたいトレーナーのもとへ通うことが難しい状況がありました。


ボクシングは自主練は当たり前のスポーツで、場所に依存することが多く、
距離の問題で学びの機会が制限されてしまいます。

この課題を解決するため、
距離を超えてトレーナーからアドバイスを受けられる
FightHub（仮）を開発しました。


## 使い方（How）
1. ユーザー登録を行います  
2. memberユーザーはリクエストを投稿します  
3. trainerユーザーはリクエストに対してアドバイスを投稿します  
4. 投稿されたアドバイスを確認できます  


## 前提条件 / 実行環境
・Ruby 3.3.10  
・Ruby on Rails 7.1.6  
・Devise  
・SQLite3  
・HTML / CSS  


## 開発環境の構築（Docker）

次の手順で、ローカルに Ruby を入れなくても同じアプリを起動できます。

**前提:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) をインストール済みであること。

1. このリポジトリを clone し、プロジェクトのルートに移動する。
2. ターミナルで次を実行する。

```bash
docker compose up --build
```

3. ブラウザで次を開く（`https` ではなく **`http`**）。

```
http://127.0.0.1:3000
```

4. 止めるときはターミナルで `Ctrl+C` のあと、次を実行する。

```bash
docker compose down
```

**うまくいかないとき:** ポート 3000 を別のアプリが使っている場合は、そのアプリを止める。`Gemfile` を変更した直後なら、次を実行してから再度手順 2 へ。

```bash
docker compose run --rm web bundle install
```

## 開発用サンプルデータ

- member 3人
- trainer 3人
- request 5件
- advice 3件（2件の request は未返信の状態）

### テストアカウント

共通パスワード: `password123`

- member1@example.test（テストメンバー1）
- member2@example.test（テストメンバー2）
- member3@example.test（テストメンバー3）
- trainer1@example.test（テストトレーナー1）
- trainer2@example.test（テストトレーナー2）
- trainer3@example.test（テストトレーナー3）

### シード投入

- ローカルで実行: `bin/rails db:seed`
- Docker で実行（起動中）: `docker compose exec web bin/rails db:seed`
- Docker で実行（停止中）: `docker compose run --rm web bin/rails db:seed`



## ライセンス
MIT


## 作者 / リンク（任意）

作成者: Sho Inanaga  
GitHub: https://github.com/and1-sho  