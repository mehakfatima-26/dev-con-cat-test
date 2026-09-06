class LayerResult < ApplicationRecord
  enum :state, { not_applicable: 0, completed: 1, errored: 2, skipped: 3 }
  enum :result, { pass: 0, warn: 1, fail: 2 }

  belongs_to :verification_run

  validates :layer_key, presence: true, inclusion: { in: DetectionLayer::KEYS },
    uniqueness: { scope: :verification_run_id }
  validates :detail, presence: true
  validates :result, presence: true, if: :completed?
  validates :result, absence: true, unless: :completed?
end
