class Lead < ApplicationRecord
  URL_FORMAT = URI::DEFAULT_PARSER.make_regexp(%w[http https])
  PHONE_FORMAT = /\A\+[1-9]\d{6,14}\z/
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  belongs_to :account
  belongs_to :pixel
  belongs_to :capture_session, optional: true
  has_one :verification_run, dependent: :restrict_with_error
  has_one :certificate, through: :verification_run

  validates :lead_id, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT }
  validates :phone, presence: true, format: { with: PHONE_FORMAT }
  validates :ip_address, presence: true
  validates :landing_page_url, presence: true, format: { with: URL_FORMAT }
  validates :trusted_form_cert_url, format: { with: URL_FORMAT }, allow_blank: true
  validates :form_dwell_ms, numericality: { greater_than_or_equal_to: 0 }
  validates :captured_at, presence: true
  validate :tenant_references_consistent

  private

  def tenant_references_consistent
    if pixel.present? && account.present? && account_id != pixel.account_id
      errors.add(:account_id, "must match the pixel's account")
    end

    return if capture_session.blank?

    if pixel_id != capture_session.pixel_id
      errors.add(:capture_session_id, "must belong to the same pixel as this lead")
    end
    if account_id != capture_session.account_id
      errors.add(:capture_session_id, "must belong to the same account as this lead")
    end
  end
end
