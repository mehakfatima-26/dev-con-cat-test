class CrmRecord < ApplicationRecord
  PHONE_FORMAT = /\A\+[1-9]\d{6,14}\z/

  belongs_to :account
  belongs_to :lead, optional: true

  validates :crm_id, presence: true, uniqueness: { scope: :account_id }
  validates :lead_id, uniqueness: true, allow_nil: true
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true, format: { with: PHONE_FORMAT }
  validates :crm_created_at, presence: true
  validate :lead_belongs_to_same_account

  private

  def lead_belongs_to_same_account
    return if lead.blank?

    errors.add(:lead_id, "must belong to the same account") if lead.account_id != account_id
  end
end
