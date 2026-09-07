class Certificate < ApplicationRecord
  belongs_to :verification_run

  delegate :lead, :account, :policy_version, to: :verification_run

  validates :serial, presence: true, uniqueness: true
  validates :payload, :payload_sha256, :signature, presence: true
  validates :issued_at, presence: true
  validates :incomplete_reason, presence: true, if: :incomplete?
  before_update :reject_update

  def self.canonical_json(value)
    case value
    when Hash
      pairs = value.keys.sort_by(&:to_s).map { |k| "#{k.to_s.to_json}:#{canonical_json(value[k])}" }
      "{#{pairs.join(',')}}"
    when Array
      "[#{value.map { |v| canonical_json(v) }.join(',')}]"
    else
      value.to_json
    end
  end

  private

  def reject_update
    raise ActiveRecord::ReadOnlyRecord, "Certificate is immutable once issued"
  end
end
