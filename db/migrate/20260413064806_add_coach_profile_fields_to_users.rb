class AddCoachProfileFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    # 公開プロフィール URL と最終訪問時刻
    add_column :users, :slug, :string
    add_column :users, :last_seen_at, :datetime

    # プロフィール本文と経歴
    add_column :users, :profile_affiliation, :string
    add_column :users, :profile_prefecture, :string
    add_column :users, :profile_area_detail, :string
    add_column :users, :boxing_started_on, :date
    add_column :users, :coaching_started_on, :date
    add_column :users, :profile_bio, :text

    # 6軸レーダー（各 0〜5、初期値 0）
    add_column :users, :radar_attack, :integer, default: 0, null: false
    add_column :users, :radar_technique, :integer, default: 0, null: false
    add_column :users, :radar_physical, :integer, default: 0, null: false
    add_column :users, :radar_speed, :integer, default: 0, null: false
    add_column :users, :radar_strategy, :integer, default: 0, null: false
    add_column :users, :radar_defense, :integer, default: 0, null: false

    # slug の重複を DB レベルで禁止
    add_index :users, :slug, unique: true
  end
end