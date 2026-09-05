require "rails_helper"

RSpec.describe "Current attributes" do
  it "sets Current.user and Current.account from the signed-in session" do
    account = create(:account, company_name: "Current Attrs Test Co")
    user = create(:user, account: account)
    sign_in user

    get root_path

    expect(response.body).to include(user.email)
    expect(response.body).to include("Current Attrs Test Co")
  end

  it "leaves Current.account blank for a super_admin" do
    admin = create(:user, :super_admin)
    sign_in admin

    get root_path

    expect(response.body).to include("none (super_admin)")
  end

  it "redirects an unauthenticated request instead of raising" do
    get root_path

    expect(response).to redirect_to(new_user_session_path)
  end
end
