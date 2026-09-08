require "rails_helper"

RSpec.describe "Api::Pixel::Activities" do
  let(:pixel) { create(:pixel, allowed_origins: %w[https://buyer-landing.example]) }
  let(:lead) { create(:lead, account: pixel.account, pixel: pixel) }
  let(:headers) { { "Origin" => "https://buyer-landing.example" } }

  def stream_token_for(lead)
    Rails.application.message_verifier(:pixel_activity_stream).generate(lead.id, expires_in: 1.hour)
  end

  def get_activity(lead_id: lead.lead_id, token: stream_token_for(lead), request_headers: headers)
    get "/api/pixel/leads/#{lead_id}/activity", params: { token: token }, headers: request_headers
  end

  it "streams every existing layer result, then the final verdict" do
    run = create(:verification_run, :completed, lead: lead, reasons: [ "vpn_proxy: no signals" ])
    create(:layer_result, verification_run: run, layer_key: "vpn_proxy", result: :pass, detail: "vpn_proxy: no signals")
    create(:layer_result, verification_run: run, layer_key: "anura", result: :warn, detail: "Anonymizer IP (Anura)")

    get_activity

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("event: layer_result").twice
    expect(response.body).to include(%("layer":"vpn_proxy","verdict":"pass","detail":"vpn_proxy: no signals"))
    expect(response.body).to include(%("layer":"anura","verdict":"warn","detail":"Anonymizer IP (Anura)"))
    expect(response.body).to include("event: final_verdict")
    expect(response.body).to include(%("verdict":"accept","score":"0.95"))
  end

  it "includes the certificate's serial in the final_verdict event once one has been issued" do
    run = create(:verification_run, :completed, lead: lead)
    certificate = create(:certificate, verification_run: run)

    get_activity

    expect(response.body).to include(%("certificate_serial":"#{certificate.serial}"))
  end

  it "omits certificate_serial (rather than erroring) when the run has no certificate yet" do
    create(:verification_run, :completed, lead: lead)

    get_activity

    expect(response.body).to include(%("certificate_serial":null))
  end

  it "rejects a missing/invalid token" do
    get_activity(token: "not-a-real-token")

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a token whose lead doesn't match the requested lead_id" do
    other_lead = create(:lead, account: pixel.account, pixel: pixel)
    create(:verification_run, :completed, lead: lead)

    get_activity(lead_id: other_lead.lead_id, token: stream_token_for(lead))

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a disallowed origin even with a valid token" do
    create(:verification_run, :completed, lead: lead)

    get_activity(request_headers: { "Origin" => "https://attacker.example" })

    expect(response).to have_http_status(:forbidden)
  end
end
