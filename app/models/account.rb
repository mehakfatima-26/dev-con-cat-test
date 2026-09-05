class Account < ApplicationRecord
  enum :plan, { starter: 0, growth: 1, enterprise: 2 }
  enum :status, { active: 0, past_due: 1, suspended: 2 }

  has_many :users, dependent: :restrict_with_error
  has_one :pixel, dependent: :restrict_with_error
  has_many :capture_sessions, dependent: :restrict_with_error
  has_many :leads, dependent: :restrict_with_error
  has_one :consensus_policy, dependent: :restrict_with_error
  has_many :credit_transactions, dependent: :restrict_with_error
  has_many :crm_records, dependent: :restrict_with_error

  validates :account_id, presence: true, uniqueness: true
  validates :company_name, presence: true
  validates :billing_contact, presence: true
  validates :monthly_credit_allowance, numericality: { greater_than_or_equal_to: 0 }
  validates :avg_daily_burn, numericality: { greater_than_or_equal_to: 0 }
  validates :cycle_start, :cycle_end, presence: true
  validate :cycle_end_after_cycle_start
  validate :enabled_modules_are_known_layers

  def credits_used_this_cycle
    -credit_transactions.where(created_at: cycle_start..cycle_end).sum(:amount)
  end

  def credits_remaining
    monthly_credit_allowance - credits_used_this_cycle
  end

  private

  def cycle_end_after_cycle_start
    return if cycle_start.blank? || cycle_end.blank?

    errors.add(:cycle_end, "must be after cycle_start") if cycle_end <= cycle_start
  end

  def enabled_modules_are_known_layers
    unknown = enabled_modules.to_a - DetectionLayer::KEYS
    errors.add(:enabled_modules, "contains unknown module(s): #{unknown.join(', ')}") if unknown.any?
  end
end
