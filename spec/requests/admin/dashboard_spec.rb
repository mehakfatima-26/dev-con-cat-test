require "rails_helper"

RSpec.describe "Admin::Dashboard" do
  it "shows every account with correct plan/status/credit numbers to a super_admin" do
    account = create(:account, company_name: "Acme Leads", plan: :growth, status: :active,
      monthly_credit_allowance: 10_000)
    pixel = create(:pixel, account: account)
    lead = create(:lead, account: account, pixel: pixel)
    run = create(:verification_run, :completed, lead: lead)
    create(:credit_transaction, account: account, verification_run: run, layer_key: "anura", amount: -400)

    sign_in create(:user, :super_admin)
    get "/admin"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Acme Leads")
    expect(response.body).to include("Growth")
    expect(response.body).to include("10,000") # allowance
    expect(response.body).to include("400") # used
    expect(response.body).to include("9,600") # remaining
  end

  it "flags an at-risk account and does not flag a healthy one" do
    at_risk = create(:account, company_name: "Risky Co", status: :past_due)
    healthy = create(:account, company_name: "Healthy Co", status: :active,
      monthly_credit_allowance: 100_000)

    sign_in create(:user, :super_admin)
    get "/admin"

    body = response.body
    risky_row = body[/<tr[^>]*>(?:(?!<\/tr>).)*Risky Co.*?<\/tr>/m]
    healthy_row = body[/<tr[^>]*>(?:(?!<\/tr>).)*Healthy Co.*?<\/tr>/m]

    expect(risky_row).to include("AT RISK")
    expect(healthy_row).not_to include("AT RISK")
  end

  it "offers a way to sign out" do
    sign_in create(:user, :super_admin)
    get "/admin"

    expect(response.body).to include(destroy_user_session_path)

    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)

    get "/admin"
    expect(response).to redirect_to(new_user_session_path)
  end

  it "lists each account's own users, by name and role, for the super_admin" do
    account = create(:account, company_name: "Acme Leads")
    create(:user, account: account, name: "Dana Whitfield", role: :account_admin)
    create(:user, account: account, name: "Luis Fernandez", role: :member)

    sign_in create(:user, :super_admin)
    get "/admin"

    body = response.body
    row = body[/<tr[^>]*>(?:(?!<\/tr>).)*Acme Leads.*?<\/tr>/m]

    expect(row).to include("Dana Whitfield")
    expect(row).to include("Account Admin")
    expect(row).to include("Luis Fernandez")
    expect(row).to include("Member")
  end

  it "links out to the all-accounts leads view" do
    sign_in create(:user, :super_admin)
    get "/admin"

    expect(response.body).to include(leads_path)
    expect(response.body).to include("All Leads")
  end

  it "denies a non-super_admin" do
    sign_in create(:user, role: :account_admin, account: create(:account))
    get "/admin"

    expect(response).to redirect_to(root_path)
  end

  it "redirects an unauthenticated visitor to sign in" do
    get "/admin"

    expect(response).to redirect_to(new_user_session_path)
  end
end
