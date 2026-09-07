class Rack::Attack
  throttle("pixel/visit/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/api/pixel/visit" && req.post?
  end

  throttle("pixel/leads/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/pixel/leads" && req.post?
  end

  throttle("pixel/activity/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{\A/api/pixel/leads/[^/]+/activity\z}) && req.get?
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    [ 429, { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s }, [ { error: "rate limited" }.to_json ] ]
  end
end
