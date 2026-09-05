class CreditTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :verification_run

  validates :amount, presence: true, numericality: { less_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :layer_key, presence: true, inclusion: { in: DetectionLayer::KEYS }
end
