require "rails_helper"

RSpec.describe "Api::Pixel::Leads" do
  before do
    global_policy = ConsensusPolicy.find_by(account: nil) || create(:consensus_policy, account: nil)
    global_policy.update!(active_policy_version: create(:policy_version, consensus_policy: global_policy)) if global_policy.active_policy_version.nil?
  end

  let(:pixel) { create(:pixel, allowed_origins: %w[https://buyer-landing.example]) }
  let(:capture_session) { create(:capture_session, pixel: pixel, account: pixel.account, page_url: "https://buyer-landing.example/quote") }
  let(:valid_headers) { { "Origin" => "https://buyer-landing.example" } }
  let(:valid_params) do
    { session_id: capture_session.session_id, pixel_id: pixel.pixel_id, submitted_at: "2026-07-14T15:05:00Z",
      form_dwell_ms: 12_000, fields: { first_name: "Jane", last_name: "Doe", email: "jane@example.com", phone: "+13105550100" } }
  end

  def post_lead(params: valid_params, headers: valid_headers)
    post "/api/pixel/leads", params: params, headers: headers, as: :json
  end

  it "creates a lead, enqueues verification, and returns lead_id + stream_token" do
    expect { post_lead }.to have_enqueued_job(Verification::RunLayersJob)
      .and change(Lead, :count).by(1)
      .and change(VerificationRun, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["lead_id"]).to match(/\AL-/)
    expect(body["stream_token"]).to be_present

    lead = Lead.last
    expect(lead.capture_session).to eq(capture_session)
    expect(lead.account).to eq(pixel.account)
    expect(lead.landing_page_url).to eq(capture_session.page_url)
  end

  it "is idempotent on session_id -- a retried submit returns the existing lead, no second run" do
    post_lead
    first_lead_id = JSON.parse(response.body)["lead_id"]

    expect { post_lead }.not_to change(Lead, :count)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["lead_id"]).to eq(first_lead_id)
  end

  it "rejects a submission with no matching capture session" do
    post_lead(params: valid_params.merge(session_id: "sess_never_visited"))

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an unknown pixel" do
    post_lead(params: valid_params.merge(pixel_id: "px_nonexistent"))

    expect(response).to have_http_status(:forbidden)
  end

  it "returns 422 for missing required fields" do
    post_lead(params: valid_params.merge(fields: { first_name: "Jane" }))

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects a hard CRM duplicate (same phone AND email) before creating a Lead, a run, or any charge" do
    create(:crm_record, account: pixel.account, crm_id: "CRM-EXISTING", phone: "+13105550100", email: "jane@example.com")

    expect { post_lead }.to change(Lead, :count).by(0)
      .and change(VerificationRun, :count).by(0)
      .and change(CreditTransaction, :count).by(0)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["verdict"]).to eq("reject")
    expect(body["reasons"].join).to include("CRM-EXISTING")
    expect(body).not_to have_key("lead_id")
  end

  it "does not short-circuit a soft duplicate (only phone or only email matches) -- the full run still executes" do
    create(:crm_record, account: pixel.account, crm_id: "CRM-SOFT", phone: "+13105550100", email: "someone-else@example.com")

    expect { post_lead }.to change(Lead, :count).by(1).and change(VerificationRun, :count).by(1)
    expect(response).to have_http_status(:created)
  end

  it "surfaces prior non-accepted attempts for the same identity -- visibility, not a discount, the charge still applies" do
    earlier_lead = create(:lead, account: pixel.account, pixel: pixel, phone: "+13105550100", email: "jane@example.com")
    create(:verification_run, :completed, lead: earlier_lead, verdict: :review)

    expect { post_lead }.to change(VerificationRun, :count).by(1)

    body = JSON.parse(response.body)
    expect(body["prior_attempts"]).to eq("count" => 1, "verdicts" => [ "review" ])
  end

  it "reports no prior_attempts when this identity has never been checked before" do
    post_lead

    expect(JSON.parse(response.body)).not_to have_key("prior_attempts")
  end
end
