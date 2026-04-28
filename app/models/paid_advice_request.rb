class PaidAdviceRequest < ApplicationRecord
  MENU_TEXT_ONLY = Advice::TEXT_ONLY_MENU
  MENU_TEXT_WITH_VIDEO = Advice::TEXT_WITH_VIDEO_MENU
  STATUS_CHECKOUT_STARTED = "checkout_started".freeze
  STATUS_IN_PROGRESS = "in_progress".freeze
  STATUS_DELIVERED = "delivered".freeze
  STATUS_COMPLETED = "completed".freeze
  AUTO_COMPLETE_AFTER = 3.days

  belongs_to :advice
  belongs_to :request
  belongs_to :member, class_name: "User"
  belongs_to :trainer, class_name: "User"
  has_one_attached :delivery_video

  validates :menu_code, presence: true
  validates :amount_jpy, numericality: { only_integer: true, greater_than: 0 }
  validates :stripe_checkout_session_id, uniqueness: true, allow_blank: true
  validates :status, presence: true
  validates :status, inclusion: {
    in: [STATUS_CHECKOUT_STARTED, STATUS_IN_PROGRESS, STATUS_DELIVERED, STATUS_COMPLETED]
  }
  validates :delivery_body, length: { maximum: 3000 }, allow_blank: true

  scope :active_for_member, ->(member_id) { where(member_id: member_id).where.not(status: STATUS_CHECKOUT_STARTED) }
  scope :active_for_trainer, ->(trainer_id) { where(trainer_id: trainer_id).where.not(status: STATUS_CHECKOUT_STARTED) }

  def self.finalize_overdue_delivered!
    overdue_scope = where(status: STATUS_DELIVERED).where("delivered_at <= ?", AUTO_COMPLETE_AFTER.ago)
    overdue_scope.update_all(status: STATUS_COMPLETED, completed_at: Time.current, updated_at: Time.current)
  end

  def menu_label
    advice.paid_menu_label(menu_code)
  end

  def menu_label_for_transaction
    case menu_code
    when MENU_TEXT_WITH_VIDEO then "【テキスト＋動画】の追加アドバイスが購入されました。"
    when MENU_TEXT_ONLY then "テキストのみ"
    else menu_label
    end
  end

  def purchase_notice_message
    case menu_code
    when MENU_TEXT_WITH_VIDEO
      menu_label_for_transaction
    else
      "#{menu_label_for_transaction}が購入されました。"
    end
  end

  # 決済確定時刻（未設定のレコード向けに作成日時で代用）
  def payment_confirmed_at
    paid_at.presence || created_at
  end

  def in_progress?
    status == STATUS_IN_PROGRESS
  end

  def delivered?
    status == STATUS_DELIVERED
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def requires_video_delivery?
    menu_code == MENU_TEXT_WITH_VIDEO
  end

  def status_label
    case status
    when STATUS_CHECKOUT_STARTED, STATUS_IN_PROGRESS then "対応中"
    when STATUS_DELIVERED then "納品済み"
    when STATUS_COMPLETED then "完了"
    else "対応中"
    end
  end
end
