class PolicyVersion < ApplicationRecord
  RULE_TYPES = %w[hard_stop weighted].freeze

  belongs_to :consensus_policy
  belongs_to :created_by, class_name: "User", optional: true
  has_many :verification_runs, dependent: :restrict_with_error

  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :consensus_policy_id }
  validate :rules_well_formed
  validate :thresholds_well_formed
  before_update :reject_update

  private

  # rules: { signal_key => { type: "hard_stop"|"weighted", weight:, label:, enabled: } }
  # {
  #   "exact_duplicate": { "type": "hard_stop", "label": "Exact CRM duplicate", "enabled": true },
  #   "suspected_litigator": { "type": "hard_stop", "label": "Known TCPA litigator", "enabled": true },
  #   "vpn_detected": { "type": "weighted", "weight": 0.3, "label": "VPN/proxy traffic detected", "enabled": true },
  #   "invalid_traffic_type": { "type": "weighted", "weight": 0.35, "label": "Suspected bot/fraud-farm traffic", "enabled": true },
  #   "dnc_listed": { "type": "weighted", "weight": 0.25, "label": "Number on Do-Not-Call registry", "enabled": true }
  # }
  def rules_well_formed
    unless rules.is_a?(Hash) && rules.present?
      errors.add(:rules, "must be a non-empty object of signal_key => rule")
      return
    end

    rules.each do |signal_key, rule|
      rule = rule.with_indifferent_access if rule.is_a?(Hash)
      prefix = "#{signal_key}:"

      unless rule.is_a?(Hash)
        errors.add(:rules, "#{prefix} must be an object")
        next
      end

      unless RULE_TYPES.include?(rule["type"])
        errors.add(:rules, "#{prefix} type must be one of #{RULE_TYPES.join('/')}")
      end
      if rule["type"] == "weighted" && !(rule["weight"].is_a?(Numeric) && rule["weight"] > 0)
        errors.add(:rules, "#{prefix} weighted rules need a positive numeric weight")
      end
      errors.add(:rules, "#{prefix} label can't be blank") if rule["label"].blank?
      errors.add(:rules, "#{prefix} enabled must be true or false") unless [ true, false ].include?(rule["enabled"])
    end
  end

  # thresholds: { reject:, review: } -- reject is the harsher, lower-score cutoff
  # { "reject": 0.4, "review": 0.75 }
  def thresholds_well_formed
    unless thresholds.is_a?(Hash)
      errors.add(:thresholds, "must be an object with reject/review keys")
      return
    end

    t = thresholds.with_indifferent_access
    if !t["reject"].is_a?(Numeric) || !t["review"].is_a?(Numeric)
      errors.add(:thresholds, "reject and review must both be numeric")
    elsif t["reject"] >= t["review"]
      errors.add(:thresholds, "reject must be lower than review")
    end
  end

  def reject_update
    raise ActiveRecord::ReadOnlyRecord, "PolicyVersion is immutable once created"
  end
end
