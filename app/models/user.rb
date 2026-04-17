class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # トレーナープロフィール用の画像
  has_one_attached :avatar_image
  has_one_attached :header_image
  # 作成時に slug が空なら自動採番する
  before_validation :assign_slug, on: :create

  enum role: { member: 0, trainer: 1 }
  # 地域（都道府県）は入力候補を固定
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
  STANCES = ["オーソドックス", "サウスポー", "スイッチ"].freeze
  WEIGHT_CLASSES = [
    "ミニマム級（〜47.62kg）",
    "ライトフライ級（47.63〜48.97kg）",
    "フライ級（48.98〜50.80kg）",
    "スーパーフライ級（50.81〜52.16kg）",
    "バンタム級（52.17〜53.52kg）",
    "スーパーバンタム級（53.53〜55.34kg）",
    "フェザー級（55.35〜57.15kg）",
    "スーパーフェザー級（57.16〜58.97kg）",
    "ライト級（58.98〜61.23kg）",
    "スーパーライト級（61.24〜63.50kg）",
    "ウェルター級（63.51〜66.68kg）",
    "スーパーウェルター級（66.69〜69.85kg）",
    "ミドル級（69.86〜72.57kg）",
    "スーパーミドル級（72.58〜76.20kg）",
    "ライトヘビー級（76.21〜79.38kg）",
    "クルーザー級（79.39〜90.72kg）",
    "ヘビー級（90.73kg〜）"
  ].freeze

  # ユーザーの名前を必須項目にする
  validates :name, presence: true
  # ユーザーの識別（member か trainer / 表示はメンバー・トレーナー）を必須項目にする
  validates :role, presence: true
  # URL 用 slug は重複不可（未入力時は自動生成）
  validates :slug, uniqueness: true, allow_blank: true
  validates :profile_prefecture, inclusion: { in: PREFECTURES }, allow_blank: true
  validates :stance, inclusion: { in: STANCES }, allow_blank: true
  validates :weight_class, inclusion: { in: WEIGHT_CLASSES }, allow_blank: true

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
  # メンバーから指定されたトレーナー宛リクエスト（一覧外）
  has_many :directed_requests, class_name: "Request", foreign_key: :directed_to_trainer_id, inverse_of: :directed_to_trainer
  # トレーナーは複数のアドバイスを持つ
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

  def instruction_experience_label
    experience_label_from(instruction_started_on)
  end

  # 誕生日から年齢を計算して表示用文字列を返す
  def age_label
    return "未設定" if birth_date.blank?

    today = Date.current
    age = today.year - birth_date.year
    # うるう年生まれは平年時に 2/28 を誕生日扱いにする
    birthday_day = [birth_date.day, Date.civil(today.year, birth_date.month, -1).day].min
    birthday_this_year = Date.new(today.year, birth_date.month, birthday_day)
    age -= 1 if today < birthday_this_year

    "#{age}歳"
  end

  # トレーナープロフィールの最低入力が埋まっているか
  def trainer_profile_completed?
    return false unless trainer?

    profile_affiliation.present? &&
      profile_prefecture.present? &&
      instruction_started_on.present? &&
      profile_bio.present?
  end

  # メンバープロフィールの最低入力が埋まっているか
  def member_profile_completed?
    return false unless member?

    profile_affiliation.present? &&
      profile_prefecture.present? &&
      boxing_started_on.present? &&
      birth_date.present? &&
      stance.present? &&
      weight_class.present? &&
      profile_bio.present?
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

  # /trainers/:slug のような URL を使う
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

    # 英数字の URL 文字列を作る。日本語名のみでも role 別の採番で補完する
    fallback = trainer? ? "trainer" : "member"
    base = name.to_s.parameterize.presence || fallback
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
