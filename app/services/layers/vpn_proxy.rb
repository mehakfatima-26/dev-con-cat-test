module Layers
  class VpnProxy < Base
    KEY = "vpn_proxy"

    def call
      hard_stop = detected_signals.find { |signal| hard_stop_signals.include?(signal) }
      return fail_result("VPN/proxy: #{signal_label(hard_stop)}") if hard_stop

      evaluate_weighted
    end

    private

    def anonymization_signal
      return "tor_exit" if fixture["is_tor"]
      return "proxy_detected" if fixture["is_proxy"]
      return "vpn_detected" if fixture["is_vpn"]
    end

    def detected_signals
      [
        anonymization_signal,
        ("datacenter_ip" if fixture["is_datacenter"]),
        ("ip_mismatch" if fixture["site_visit_ip_matches_submit_ip"] == false)
      ].compact
    end

    def hard_stop_signals
      rules["hard_stop"] || []
    end

    def weighted_rules
      rules["weighted"] || {}
    end

    def max_weight
      rules["max_weight"] || Float::INFINITY
    end

    def signal_label(signal)
      weighted_rules.dig(signal, "label") || unrecognized(signal)
    end

    def evaluate_weighted
      descriptions, signal_weight = describe_signals(detected_signals)
      risk_weight, risk_label, risk_known = describe_risk

      weight = [ [ signal_weight, risk_weight ].max, max_weight ].min
      return pass_result("vpn_proxy: no signals detected, risk: #{fixture['risk']}") if weight.zero? && risk_known

      descriptions << risk_label if risk_weight >= signal_weight
      descriptions << fixture["notes"] if fixture["notes"].present?

      warn_result(descriptions.join("; "), weight)
    end

    def describe_signals(signals)
      weight = 0.0

      descriptions = signals.map do |signal|
        rule = weighted_rules[signal]

        if rule
          weight += rule["weight"]
          rule["label"]
        else
          unrecognized(signal)
        end
      end

      [ descriptions, weight ]
    end

    def describe_risk
      rule = weighted_rules["risk_#{fixture['risk']}"]
      return [ rule["weight"], rule["label"], true ] if rule

      [ 0.0, unrecognized(fixture["risk"]), false ]
    end
  end
end
