class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      # 通知を受け取るユーザー
      t.references :user, null: false, foreign_key: true
      # 関連するリクエスト（一覧から詳細へ飛ぶため）
      t.references :request, null: false, foreign_key: true
      # 種類（例: advice_received / new_request / request_body_updated）
      t.string :kind, null: false
      # 一覧に表示する文面（作成時点の文言を保存）
      t.text :message, null: false

      t.timestamps
    end

    add_index :notifications, [:user_id, :created_at]
  end
end
