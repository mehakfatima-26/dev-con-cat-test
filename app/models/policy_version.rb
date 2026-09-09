class PolicyVersion < ApplicationRecord
  belongs_to :consensus_policy
  belongs_to :created_by, class_name: "User", optional: true
  has_many :verification_runs, dependent: :restrict_with_error

  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :consensus_policy_id }
  before_update :reject_update

  private

  def reject_update
    raise ActiveRecord::ReadOnlyRecord, "PolicyVersion is immutable once created"
  end
end
