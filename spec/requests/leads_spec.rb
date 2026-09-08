require "rails_helper"

RSpec.describe "Leads (CRM)" do
  let(:account_a) { create(:account, company_name: "Account A Co") }
  let(:account_b) { create(:account, company_name: "Account B Co") }
  let(:member_a) { create(:user, role: :member, account: account_a) }

  def lead_with_run(account, attrs: {}, run_attrs: {})
    pixel = Pixel.find_by(account: account) || create(:pixel, account: account)
    lead = create(:lead, account: account, pixel: pixel, **attrs)
    run = create(:verification_run, :completed, lead: lead, **run_attrs)
    [ lead, run ]
  end

  describe "GET /leads (index)" do
    it "shows only the signed-in user's own account's leads, never another account's" do
      own_lead, = lead_with_run(account_a, attrs: { first_name: "Alice" })
      foreign_lead, = lead_with_run(account_b, attrs: { first_name: "Bob" })

      sign_in member_a
      get "/leads"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own_lead.lead_id)
      expect(response.body).not_to include(foreign_lead.lead_id)
    end

    it "searches by name, email, phone, and lead_id" do
      target, = lead_with_run(account_a, attrs: { first_name: "Zelda", last_name: "Ng", email: "zelda@example.com" })
      other, = lead_with_run(account_a, attrs: { first_name: "Someone", last_name: "Else" })

      sign_in member_a
      get "/leads", params: { q: "zelda" }

      expect(response.body).to include(target.lead_id)
      expect(response.body).not_to include(other.lead_id)
    end

    it "filters by verdict" do
      accepted, = lead_with_run(account_a, run_attrs: { verdict: :accept })
      rejected, = lead_with_run(account_a, run_attrs: { verdict: :reject })

      sign_in member_a
      get "/leads", params: { verdict: "reject" }

      expect(response.body).to include(rejected.lead_id)
      expect(response.body).not_to include(accepted.lead_id)
    end

    it "redirects an unauthenticated visitor to sign in" do
      get "/leads"

      expect(response).to redirect_to(new_user_session_path)
    end

    it "lets a super_admin see every account's leads, labeled 'All Leads' with an Account column -- not called 'CRM'" do
      lead_a, = lead_with_run(account_a)
      lead_b, = lead_with_run(account_b)

      sign_in create(:user, :super_admin)
      get "/leads"

      expect(response.body).to include(lead_a.lead_id)
      expect(response.body).to include(lead_b.lead_id)
      expect(response.body).to include("Account A Co")
      expect(response.body).to include("Account B Co")
      expect(response.body).to include("All Leads")
      expect(response.body).not_to include(">CRM<")
    end

    it "labels the page 'CRM' for an account_admin/member, with no cross-account Account column" do
      lead_with_run(account_a)

      sign_in member_a
      get "/leads"

      expect(response.body).to include(">CRM<")
      expect(response.body).not_to include("<th>Account</th>")
    end
  end

  describe "GET /leads/:id (show)" do
    it "shows the lead's own-account detail, per-layer breakdown, and certificate link" do
      lead, run = lead_with_run(account_a, run_attrs: { verdict: :accept })
      create(:layer_result, verification_run: run, layer_key: "anura", state: :completed, result: :pass, detail: "clean")
      certificate = create(:certificate, verification_run: run)

      sign_in member_a
      get "/leads/#{lead.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(lead.email)
      expect(response.body).to include("Anura")
      expect(response.body).to include(certificate.serial)
    end

    it "shows layers the account never enabled as 'Not enabled', not conflated with a real result" do
      lead, run = lead_with_run(account_a, run_attrs: { enabled_modules_snapshot: %w[anura] })
      create(:layer_result, verification_run: run, layer_key: "anura", state: :completed, result: :pass, detail: "clean")

      sign_in member_a
      get "/leads/#{lead.id}"

      body = response.body
      voice_row = body[/<tr>(?:(?!<\/tr>).)*Voice.*?<\/tr>/m]

      expect(voice_row).to include("Not enabled")
    end

    it "returns 404, not 403, for another account's lead -- no existence leak" do
      foreign_lead, = lead_with_run(account_b)

      sign_in member_a
      get "/leads/#{foreign_lead.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
