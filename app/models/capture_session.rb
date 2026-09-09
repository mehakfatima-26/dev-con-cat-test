class CaptureSession < ApplicationRecord
  URL_FORMAT = URI::DEFAULT_PARSER.make_regexp(%w[http https])

  belongs_to :pixel
  belongs_to :account
  has_one :lead, dependent: :restrict_with_error

  validates :session_id, presence: true, uniqueness: true
  validates :page_url, presence: true, format: { with: URL_FORMAT }
  validates :referrer, format: { with: URL_FORMAT }, allow_blank: true
  validates :visit_ip, presence: true
  validates :started_at, presence: true
  validate :account_matches_pixels_account

  private

  def account_matches_pixels_account
    return if pixel.blank? || account.blank?

    errors.add(:account_id, "must match the pixel's account") if account_id != pixel.account_id
  end
end
