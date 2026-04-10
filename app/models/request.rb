class Request < ApplicationRecord

  # requestのタイトルを必須項目にする
  validates :title, presence: true
  # requestのボディーを必須項目にする
  validates :body, presence: true

  # requestはユーザーに属する
  belongs_to :user
  # requestは一つのadviceを持つ（相談削除時はアドバイスも消す）
  has_one :advice, dependent: :destroy
  # この相談に紐づく通知（相談削除時は通知も消す）
  has_many :notifications, dependent: :destroy
end
