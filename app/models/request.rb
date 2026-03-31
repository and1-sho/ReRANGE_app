class Request < ApplicationRecord

  # requestのタイトルを必須項目にする
  validates :title, presence: true
  # requestのボディーを必須項目にする
  validates :body, presence: true

  # requestはユーザーに属する
  belongs_to :user
  # requestは一つのadviceを持つ
  has_one :advice
end
