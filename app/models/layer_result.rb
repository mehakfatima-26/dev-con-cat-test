class LayerResult < ApplicationRecord
  enum :state, { not_enabled: 0, not_applicable: 1, completed: 2, errored: 3, skipped: 4 }

  belongs_to :verification_run

  validates :layer_key, presence: true, inclusion: { in: DetectionLayer::KEYS },
    uniqueness: { scope: :verification_run_id }
end
