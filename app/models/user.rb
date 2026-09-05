class User < ApplicationRecord
  devise :database_authenticatable

  enum :role, { super_admin: 0, account_admin: 1, member: 2 }

  belongs_to :account, optional: true

  validates :user_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :account_id, absence: true, if: :super_admin?
  validates :account_id, presence: true, unless: :super_admin?
end
