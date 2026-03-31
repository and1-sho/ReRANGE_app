class Advice < ApplicationRecord
  # adviceのボディーを必須項目にする
  validates :body, presence: true

  # adviceはrequestに属する
  belongs_to :request

  # adviceはcoachに属する
  belongs_to :user
end
