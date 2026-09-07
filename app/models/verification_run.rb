class VerificationRun < ApplicationRecord
  enum :status, { pending: 0, running: 1, completed: 2, partial: 3 }
  enum :verdict, { accept: 0, review: 1, reject: 2 }, suffix: true

  belongs_to :lead
  belongs_to :policy_version
  has_many :layer_results, dependent: :restrict_with_error
  has_one :certificate, dependent: :restrict_with_error
  has_many :credit_transactions, dependent: :restrict_with_error

  delegate :account, to: :lead

  validates :credits_charged, numericality: { greater_than_or_equal_to: 0 }
  validates :started_at, presence: true
  validate :verdict_matches_status
  validate :policy_matches_lead_account
  validate :enabled_modules_snapshot_are_known_layers

  after_commit :publish_final_verdict, on: :update

  private

  def publish_final_verdict
    return unless saved_change_to_status? && status.in?(%w[completed partial])

    Verification::ActivityPublisher.publish_final_verdict(self)
  end

  def enabled_modules_snapshot_are_known_layers
    unknown = enabled_modules_snapshot.to_a - DetectionLayer::KEYS
    errors.add(:enabled_modules_snapshot, "contains unknown module(s): #{unknown.join(', ')}") if unknown.any?
  end

  def verdict_matches_status
    finished = status.in?(%w[completed partial])

    if finished && verdict.blank?
      errors.add(:verdict, "must be set once a run is completed or partial")
    elsif !finished && verdict.present?
      errors.add(:verdict, "can't be set before a run is completed or partial")
    end
  end

  def policy_matches_lead_account
    return if policy_version.blank? || lead.blank?

    policy_account_id = policy_version.consensus_policy.account_id
    if policy_account_id.present? && policy_account_id != lead.account_id
      errors.add(:policy_version_id, "must be the global default or belong to the lead's account")
    end
  end
end
