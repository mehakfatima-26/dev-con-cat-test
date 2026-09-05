class Certificate < ApplicationRecord
  belongs_to :verification_run

  delegate :lead, :account, :policy_version, to: :verification_run

  validates :serial, presence: true, uniqueness: true
  validates :payload, :payload_sha256, :signature, presence: true
  validates :issued_at, presence: true
  validates :incomplete_reason, presence: true, if: :incomplete?
  before_update :reject_update

  private

  def reject_update
    raise ActiveRecord::ReadOnlyRecord, "Certificate is immutable once issued"
  end
end
