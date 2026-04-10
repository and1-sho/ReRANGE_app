class Notification < ApplicationRecord
  # 通知を受け取るユーザー
  belongs_to :user
  # 関連する相談
  belongs_to :request

  validates :kind, presence: true
  validates :message, presence: true

  # read_at が無い＝未読
  scope :unread, -> { where(read_at: nil) }
end
