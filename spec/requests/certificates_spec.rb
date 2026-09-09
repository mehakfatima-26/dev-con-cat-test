require "rails_helper"

RSpec.describe "Certificate verification" do
  def issue_certificate
    account = create(:account)
    pixel = create(:pixel, account: account)
    lead = create(:lead, account: account, pixel: pixel)
    run = create(:verification_run, :completed, lead: lead)
    create(:layer_result, verification_run: run)
    Certificates::Issuer.call(run)
  end

  it "shows a valid certificate on the HTML page" do
    cert = issue_certificate

    get "/verify/#{cert.serial}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("VALID")
    expect(response.body).to include(cert.payload["verdict"].upcase)
  end

  it "returns full verification detail as JSON" do
    cert = issue_certificate

    get "/verify/#{cert.serial}.json"

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["serial"]).to eq(cert.serial)
    expect(body["valid"]).to be true
    expect(body["payload_valid"]).to be true
    expect(body["signature_valid"]).to be true
    expect(body["chain_valid"]).to be true
    expect(body["payload"]["lead_id"]).to eq(cert.payload["lead_id"])
  end

  it "returns 404 for an unknown serial, both HTML and JSON" do
    get "/verify/CERT-DOES-NOT-EXIST"
    expect(response).to have_http_status(:not_found)

    get "/verify/CERT-DOES-NOT-EXIST.json"
    expect(response).to have_http_status(:not_found)
  end

  it "flags a tampered certificate as invalid, naming which check failed" do
    cert = issue_certificate
    Certificate.where(id: cert.id).update_all(payload: cert.payload.merge("verdict" => "reject"))

    get "/verify/#{cert.serial}.json"

    body = JSON.parse(response.body)
    expect(body["valid"]).to be false
    expect(body["payload_valid"]).to be false

    get "/verify/#{cert.serial}"
    expect(response.body).to include("INVALID")
  end
end
