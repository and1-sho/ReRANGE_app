class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # コーチプロフィール用の画像
  has_one_attached :avatar_image
  has_one_attached :header_image
  # 作成時に slug が空なら自動採番する
  before_validation :assign_slug, on: :create

  enum role: { member: 0, coach: 1 }
  # 地域（都道府県）は入力候補を固定して表記ゆれを防ぐ
  PREFECTURES = %w[
    北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県
    茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
    新潟県 富山県 石川県 福井県 山梨県 長野県
    岐阜県 静岡県 愛知県 三重県
    滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県
    鳥取県 島根県 岡山県 広島県 山口県
    徳島県 香川県 愛媛県 高知県
    福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県
  ].freeze

  # ユーザーの名前を必須項目にする
  validates :name, presence: true
  # ユーザーの識別（memberかcoach）を必須項目にする
  validates :role, presence: true
  # URL 用 slug は重複不可（未入力時は自動生成）
  validates :slug, uniqueness: true, allow_blank: true
  validates :profile_prefecture, inclusion: { in: PREFECTURES }, allow_blank: true

  # レーダーは各軸 0〜5 の整数
  with_options numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 5 } do
    validates :radar_attack
    validates :radar_technique
    validates :radar_physical
    validates :radar_speed
    validates :radar_strategy
    validates :radar_defense
  end

  # レーダー合計は 20 以下（余り OK）
  validate :radar_total_must_be_20_or_less

  # ユーザーは複数のrequestを持つ
  has_many :requests
  # コーチは複数のアドバイスを持つ
  has_many :advices
  # 自分宛の通知
  has_many :notifications, dependent: :destroy

  def radar_total
    radar_attack + radar_technique + radar_physical + radar_speed + radar_strategy + radar_defense
  end

  # 開始日からの経過を「◯年◯ヶ月」で返す（未来日は 0年0ヶ月 扱い）
  def boxing_experience_label
    experience_label_from(boxing_started_on)
  end

  def coaching_experience_label
    experience_label_from(coaching_started_on)
  end

  # 「1分未満前」ではなく最小でも「1分前」にする
  def last_seen_label
    return "未記録" if last_seen_at.blank?

    minutes = ((Time.current - last_seen_at) / 60).floor
    return "1分前" if minutes < 1
    return "#{minutes}分前" if minutes < 60

    hours = (minutes / 60).floor
    return "#{hours}時間前" if hours < 24

    days = (hours / 24).floor
    "#{days}日前"
  end

  # /coaches/:slug のような URL を使う
  def to_param
    slug.presence || id.to_s
  end

  private

  def radar_total_must_be_20_or_less
    return if radar_total <= 20

    errors.add(:base, "レーダー合計は20以下にしてください")
  end

  def assign_slug
    return if slug.present?

    # 英数字の URL 文字列を作る。日本語名のみでも coach-2 のように採番可
    base = name.to_s.parameterize.presence || "coach"
    candidate = base
    sequence = 1

    while User.exists?(slug: candidate)
      sequence += 1
      candidate = "#{base}-#{sequence}"
    end

    self.slug = candidate
  end

  def experience_label_from(start_on)
    return "未設定" if start_on.blank?

    today = Date.current
    return "0年0ヶ月" if start_on > today

    total_months = (today.year * 12 + today.month) - (start_on.year * 12 + start_on.month)
    years = total_months / 12
    months = total_months % 12

    "#{years}年#{months}ヶ月"
  end
end
