module LeadsHelper
  LAYER_LABELS = {
    "vpn_proxy" => "VPN & Proxy",
    "anura" => "Anura",
    "trustedform" => "TrustedForm",
    "blacklist_alliance" => "Blacklist Alliance",
    "dnc" => "DNC",
    "phone_validation" => "Phone Validation",
    "email_validation" => "Email Validation",
    "enrichment" => "Enrichment",
    "duplicate_detection" => "Duplicate Detection",
    "voice" => "Voice"
  }.freeze

  def layer_label(layer_key)
    LAYER_LABELS.fetch(layer_key, layer_key.titleize)
  end

  def leads_page_label
    Current.user.super_admin? ? "All Leads" : "CRM"
  end

  def verdict_badge_class(verdict)
    case verdict.to_s
    when "accept" then "badge badge--accept"
    when "review" then "badge badge--review"
    when "reject" then "badge badge--reject"
    else "badge badge--neutral"
    end
  end

  def layer_state_badge_class(layer_result)
    return "badge badge--neutral" if layer_result.nil?

    case [ layer_result.state.to_s, layer_result.result.to_s ]
    in [ "completed", "pass" ] then "badge badge--accept"
    in [ "completed", "warn" ] then "badge badge--review"
    in [ "completed", "fail" ] then "badge badge--reject"
    in [ "errored", _ ] then "badge badge--reject"
    else "badge badge--neutral"
    end
  end

  def layer_state_label(layer_result)
    return "Not enabled" if layer_result.nil?

    case layer_result.state.to_s
    when "completed" then layer_result.result.to_s.upcase
    when "not_applicable" then "N/A"
    when "errored" then "ERRORED"
    when "skipped" then "SKIPPED"
    else layer_result.state.to_s.upcase
    end
  end
end
