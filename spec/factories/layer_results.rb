FactoryBot.define do
  factory :layer_result do
    verification_run { association :verification_run, strategy: :create }
    layer_key { "vpn_proxy" }
    state { :completed }
    result { :pass }
    detail { "vpn_proxy: no signals" }
    raw_response { { "is_vpn" => false, "is_proxy" => false, "risk" => "low" } }
  end
end
