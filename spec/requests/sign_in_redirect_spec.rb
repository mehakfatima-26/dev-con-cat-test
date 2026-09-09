require "rails_helper"

RSpec.describe "Sign-in redirect" do
  it "sends a super_admin straight to the admin dashboard" do
    admin = create(:user, :super_admin, password: "testpass123")

    post user_session_path, params: { user: { email: admin.email, password: "testpass123" } }

    expect(response).to redirect_to(admin_root_path)
  end

  it "sends a regular user to the generic dashboard, not the admin one" do
    user = create(:user, role: :account_admin, account: create(:account), password: "testpass123")

    post user_session_path, params: { user: { email: user.email, password: "testpass123" } }

    expect(response).to redirect_to(root_path)
  end
end
