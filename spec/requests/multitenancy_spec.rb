require "rails_helper"

RSpec.describe "Multi-tenancy and role boundaries" do
  describe "Admin:: namespace" do
    it "redirects an unauthenticated visitor to sign in" do
      get admin_root_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "blocks an account_admin from every account" do
      user = create(:user, role: :account_admin)
      sign_in user

      get admin_root_path

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("not authorized")
    end

    it "blocks a member" do
      user = create(:user, role: :member)
      sign_in user

      get admin_root_path

      expect(response).to redirect_to(root_path)
    end

    it "allows a super_admin" do
      admin = create(:user, :super_admin)
      sign_in admin

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email)
    end
  end

  describe "the tenant dashboard" do
    it "never shows another account's data -- it only ever reflects the signed-in user's own session" do
      account_a = create(:account, company_name: "Account A Co")
      account_b = create(:account, company_name: "Account B Co")
      user_a = create(:user, account: account_a)
      create(:user, account: account_b)

      sign_in user_a
      get root_path

      expect(response.body).to include("Account A Co")
      expect(response.body).not_to include("Account B Co")
    end

    it "a super_admin hitting the tenant dashboard has no account to leak" do
      admin = create(:user, :super_admin)
      sign_in admin

      get root_path

      expect(response.body).to include("none (super_admin)")
    end
  end
end
