class Pixel < ApplicationRecord
  ORIGIN_FORMAT = URI::DEFAULT_PARSER.make_regexp(%w[http https])

  enum :status, { active: 0, paused: 1 }

  belongs_to :account
  has_many :capture_sessions, dependent: :restrict_with_error
  has_many :leads, dependent: :restrict_with_error

  validates :pixel_id, presence: true, uniqueness: true
  validates :account_id, uniqueness: true
  validates :name, presence: true
  validate :allowed_origins_present_and_well_formed

  private

  def allowed_origins_present_and_well_formed
    if allowed_origins.blank?
      errors.add(:allowed_origins, "must include at least one origin")
      return
    end

    allowed_origins.each do |origin|
      errors.add(:allowed_origins, "#{origin.inspect} is not a valid http(s) origin") unless origin.match?(ORIGIN_FORMAT)
    end
  end
end
