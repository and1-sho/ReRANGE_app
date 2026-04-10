class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { member: 0, coach: 1 }
  # ユーザーの名前を必須項目にする
  validates :name, presence: true
  # ユーザーの識別（memberかcoach）を必須項目にする
  validates :role, presence: true

  # ユーザーは複数のrequestを持つ
  has_many :requests
  # コーチは複数のアドバイスを持つ
  has_many :advices
  # 自分宛の通知
  has_many :notifications, dependent: :destroy

end
