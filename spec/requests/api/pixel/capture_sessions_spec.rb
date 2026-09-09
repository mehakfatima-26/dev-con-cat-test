require "rails_helper"

RSpec.describe "Api::Pixel::CaptureSessions" do
  let(:pixel) { create(:pixel, allowed_origins: %w[https://buyer-landing.example]) }
  let(:valid_headers) { { "Origin" => "https://buyer-landing.example" } }
  let(:valid_params) do
    { session_id: "sess_abc123", pixel_id: pixel.pixel_id, page_url: "https://buyer-landing.example/quote",
      referrer: "https://google.com/search", started_at: "2026-07-14T15:00:00Z" }
  end

  def post_visit(params: valid_params, headers: valid_headers)
    post "/api/pixel/visit", params: params, headers: headers, as: :json
  end

  it "creates a capture session and returns 202" do
    expect { post_visit }.to change(CaptureSession, :count).by(1)

    expect(response).to have_http_status(:accepted)
    session = CaptureSession.last
    expect(session.pixel).to eq(pixel)
    expect(session.account).to eq(pixel.account)
  end

  it "records the server-observed IP and user agent, not client-claimed values" do
    post_visit(headers: valid_headers.merge("User-Agent" => "TestClient/1.0"))

    session = CaptureSession.last
    expect(session.user_agent).to eq("TestClient/1.0")
    expect(session.visit_ip.to_s).to be_present
  end

  it "is idempotent on session_id -- a retried beacon is a silent no-op" do
    post_visit
    expect { post_visit }.not_to change(CaptureSession, :count)

    expect(response).to have_http_status(:accepted)
  end

  it "rejects a replayed session_id claimed by a different pixel" do
    post_visit
    other_pixel = create(:pixel, allowed_origins: %w[https://buyer-landing.example])

    post_visit(params: valid_params.merge(pixel_id: other_pixel.pixel_id))

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects an unknown pixel_id" do
    post_visit(params: valid_params.merge(pixel_id: "px_nonexistent"))

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a paused pixel" do
    pixel.update!(status: :paused)

    post_visit

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a disallowed origin" do
    post_visit(headers: { "Origin" => "https://attacker.example" })

    expect(response).to have_http_status(:forbidden)
  end

  it "returns 422 for a malformed page_url" do
    post_visit(params: valid_params.merge(page_url: "not-a-url"))

    expect(response).to have_http_status(:unprocessable_content)
  end
end
