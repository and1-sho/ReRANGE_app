#!/usr/bin/env bash
#
# ============================================================
# Render 用ビルドスクリプト
#
# Render がデプロイするときにこのファイルを実行する。
# 「アプリを動かすための準備作業」を順番に行う。
# ============================================================

# どこかで失敗したらすぐ止まるようにする（エラーを見逃さないため）
set -o errexit

# ① gem（ライブラリ）をインストールする
bundle install

# ② CSS・JavaScript を本番用にビルドする（最適化・圧縮）
bundle exec rails assets:precompile

# ③ 古いキャッシュを削除する
bundle exec rails assets:clean

# ④ データベースのマイグレーションを実行する
# （まだ作られていないテーブルを作ったり、カラムを追加したりする）
bundle exec rails db:migrate
