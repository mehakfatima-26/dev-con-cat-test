module CertificatesHelper
  LAYER_LABELS = {
    "vpn_proxy" => "VPN / Proxy",
    "trustedform" => "TrustedForm",
    "dnc" => "DNC"
  }.freeze

  def layer_label(layer_key)
    LAYER_LABELS[layer_key] || layer_key.titleize
  end
end
