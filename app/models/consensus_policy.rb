class ConsensusPolicy < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :active_policy_version, class_name: "PolicyVersion", optional: true
  has_many :policy_versions, dependent: :restrict_with_error

  validates :account_id, uniqueness: true
  validates :name, presence: true
  validate :active_version_belongs_to_self

  def self.active_version_for(account)
    (find_by(account: account) || find_by(account: nil))&.active_policy_version
  end

  private

  def active_version_belongs_to_self
    return if active_policy_version.blank?

    errors.add(:active_policy_version_id, "must be a version of this same policy") if active_policy_version.consensus_policy_id != id
  end
end
