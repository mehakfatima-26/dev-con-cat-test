module Layers
  class Base
    attr_reader :lead, :rules

    def initialize(lead, rules)
      @lead = lead
      @rules = rules
    end

    def call
      raise NotImplementedError
    end

    private

    def fixture
      @fixture ||= Providers::FixtureData.for(self.class::KEY, lead.lead_id) ||
        raise(NotImplementedError, "no #{self.class::KEY} fixture for #{lead.lead_id} -- SimulatedSource isn't built yet")
    end

    def find_hard_stop
      (rules["hard_stop"] || {}).each do |field, trigger_values|
        hit = Array(fixture[field]).map { |value| value.to_s.downcase }.find { |value| trigger_values.include?(value) }
        return [ field, hit ] if hit
      end

      nil
    end

    def unrecognized(value)
      "#{value} (unrecognized signal, not yet classified in policy)"
    end

    def fail_result(detail)
      { result: "fail", detail: detail, weight: nil, raw: fixture }
    end

    def pass_result(detail)
      { result: "pass", detail: detail, weight: 0.0, raw: fixture }
    end

    def warn_result(detail, weight)
      { result: "warn", detail: detail, weight: weight, raw: fixture }
    end

    def not_applicable_result(detail)
      { result: nil, detail: detail, weight: nil, raw: fixture, not_applicable: true }
    end
  end
end
