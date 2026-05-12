# ============================================================
# PaidAdviceRequest モデル
#
# 有料アドバイスの取引を表すモデル。
# メンバーがトレーナーの有料メニューを購入すると1件作成される。
# Stripe（決済サービス）と連携してお金のやり取りを管理する。
# MVP ver.0.1.0 では機能を停止中。将来的に復活予定。
# ============================================================
class PaidAdviceRequest < ApplicationRecord
  # 有料メニューの種別コード（DB に保存される文字列）
  MENU_TEXT_ONLY       = "text_only".freeze
  MENU_TEXT_WITH_VIDEO = "text_with_video".freeze

  # 画面表示用のラベル（コードから日本語に変換するための対応表）
  MENU_LABELS = {
    MENU_TEXT_ONLY       => "詳しいテキストのみ",
    MENU_TEXT_WITH_VIDEO => "詳しいテキスト＋動画解説"
  }.freeze

  # 取引のステータス（進行状況）を表す定数
  STATUS_CHECKOUT_STARTED = "checkout_started".freeze # Stripe 決済ページを開いた直後
  STATUS_PAID_LEGACY      = "paid".freeze             # 旧ステータス（互換性のために残している）
  STATUS_IN_PROGRESS      = "in_progress".freeze      # 決済完了・納品待ち
  STATUS_DELIVERED        = "delivered".freeze        # トレーナーが納品済み
  STATUS_COMPLETED        = "completed".freeze        # メンバーが完了確認済み

  # 納品後3日経っても完了確認されない場合に自動で完了にする期間
  AUTO_COMPLETE_AFTER = 3.days

  # どのアドバイスへの有料依頼かを持つ
  belongs_to :advice
  # どのリクエストに関するものかを持つ
  belongs_to :request
  # 購入したメンバー（User テーブルを参照するが、カラム名は member_id）
  belongs_to :member,  class_name: "User"
  # 担当トレーナー（User テーブルを参照するが、カラム名は trainer_id）
  belongs_to :trainer, class_name: "User"
  # トレーナーが納品する動画（テキスト＋動画メニューの場合に使う）
  has_one_attached :delivery_video

  validates :menu_code,   presence: true
  # 金額は整数・0 より大きい必要がある
  validates :amount_jpy,  numericality: { only_integer: true, greater_than: 0 }
  # ステータスは定められた値のどれかでなければならない
  validates :status, presence: true, inclusion: {
    in: [STATUS_CHECKOUT_STARTED, STATUS_PAID_LEGACY, STATUS_IN_PROGRESS, STATUS_DELIVERED, STATUS_COMPLETED]
  }
  # Stripe のセッション ID は重複不可（空はOK）
  validates :stripe_checkout_session_id, uniqueness: true, allow_blank: true
  validates :delivery_body, length: { maximum: 3000 }, allow_blank: true

  # 特定のメンバーの「進行中の取引」を取得するスコープ（checkout_started は除外）
  scope :active_for_member,  ->(member_id)  { where(member_id: member_id).where.not(status: STATUS_CHECKOUT_STARTED) }
  # 特定のトレーナーの「進行中の取引」を取得するスコープ
  scope :active_for_trainer, ->(trainer_id) { where(trainer_id: trainer_id).where.not(status: STATUS_CHECKOUT_STARTED) }

  # 納品済みで3日以上放置されている取引を自動的に「完了」にするクラスメソッド
  # TransactionsController の before_action から毎リクエストで呼ばれる
  def self.finalize_overdue_delivered!
    where(status: STATUS_DELIVERED)
      .where("delivered_at <= ?", AUTO_COMPLETE_AFTER.ago)
      .update_all(status: STATUS_COMPLETED, completed_at: Time.current, updated_at: Time.current)
  end

  # メニューコードから日本語のラベルを返す（例: "text_only" → "詳しいテキストのみ"）
  def menu_label
    MENU_LABELS[menu_code]
  end

  # 取引詳細ページの購入通知メッセージを返す
  def menu_label_for_transaction
    case menu_code
    when MENU_TEXT_WITH_VIDEO then "【テキスト＋動画】の追加アドバイスが購入されました。"
    when MENU_TEXT_ONLY       then "テキストのみ"
    else menu_label
    end
  end

  # 購入完了時の通知文を返す
  def purchase_notice_message
    case menu_code
    when MENU_TEXT_WITH_VIDEO then menu_label_for_transaction
    else "#{menu_label_for_transaction}が購入されました。"
    end
  end

  # 取引完了時の承認メッセージを返す
  # メンバーが見る場合と、トレーナーが見る場合でメッセージを変える
  def approval_notice_message(viewer:)
    if viewer.id == member_id
      case menu_code
      when MENU_TEXT_WITH_VIDEO then "【テキスト＋動画】の追加アドバイスを承認しました。"
      when MENU_TEXT_ONLY       then "【テキストのみ】の追加アドバイスを承認しました。"
      else "追加アドバイスを承認しました。"
      end
    else
      case menu_code
      when MENU_TEXT_WITH_VIDEO then "【テキスト＋動画】の追加アドバイスが承認されました。"
      when MENU_TEXT_ONLY       then "【テキストのみ】の追加アドバイスが承認されました。"
      else "追加アドバイスが承認されました。"
      end
    end
  end

  # 決済確定の日時を返す（未設定の古いレコードはレコード作成日時で代用）
  def payment_confirmed_at
    paid_at.presence || created_at
  end

  # 決済完了・納品待ちの状態か
  def in_progress?
    status == STATUS_IN_PROGRESS || status == STATUS_PAID_LEGACY
  end

  # トレーナーが納品フォームを出していい状態か（決済済みで未納品・未完了）
  def awaiting_trainer_delivery?
    return false if delivered? || completed?
    return true  if in_progress?

    # ステータス更新が遅れた場合の救済：paid_at がある checkout_started も納品可能とする
    paid_at.present? && status == STATUS_CHECKOUT_STARTED
  end

  # 納品済みか
  def delivered?
    status == STATUS_DELIVERED
  end

  # 完了済みか
  def completed?
    status == STATUS_COMPLETED
  end

  # 動画も納品が必要なメニューか（テキスト＋動画メニューの場合 true）
  def requires_video_delivery?
    menu_code == MENU_TEXT_WITH_VIDEO
  end

  # トレーナー向け納品フォームの案内文を返す
  def delivery_form_hint_for_trainer
    if requires_video_delivery?
      "【テキスト＋動画】の購入です。テキストと動画の両方が必須です。"
    else
      "【テキストのみ】の購入です。詳しいアドバイスのテキストを入力してください（動画は不要です）。"
    end
  end

  # 取引一覧・詳細で表示するステータスの日本語ラベルを返す
  def status_label
    case status
    when STATUS_CHECKOUT_STARTED, STATUS_PAID_LEGACY, STATUS_IN_PROGRESS then "対応中"
    when STATUS_DELIVERED                                                  then "納品済み"
    when STATUS_COMPLETED                                                  then "完了"
    else "対応中"
    end
  end
end
