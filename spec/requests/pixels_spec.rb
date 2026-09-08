require "rails_helper"

RSpec.describe "Pixels" do
  let(:account) { create(:account) }
  let(:admin) { create(:user, role: :account_admin, account: account) }
  let(:member) { create(:user, role: :member, account: account) }

  describe "GET /pixel (show)" do
    it "redirects to the new-pixel form when the account has none yet" do
      sign_in admin
      get "/pixel"

      expect(response).to redirect_to(new_pixel_path)
    end

    it "shows the account's own pixel once it exists" do
      pixel = create(:pixel, account: account, pixel_id: "px_abc123")
      sign_in member
      get "/pixel"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pixel.pixel_id)
    end

    it "renders a real, absolute-URL embed snippet scoped to this pixel's id" do
      pixel = create(:pixel, account: account, pixel_id: "px_abc123")
      sign_in member
      get "/pixel"

      snippet = CGI.unescapeHTML(response.body)

      expect(snippet).to include('data-pixel-id="px_abc123"')
      expect(snippet).to include('data-endpoint="http')
      expect(snippet).to include('/api/pixel"')
      expect(snippet).to include('src="http')
      expect(snippet).to include('/super-pixel.js"')
    end

    it "is not available to a super_admin (no account to scope to)" do
      sign_in create(:user, :super_admin)
      get "/pixel"

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /pixel/new" do
    it "allows account_admin to reach the form" do
      sign_in admin
      get "/pixel/new"

      expect(response).to have_http_status(:ok)
    end

    it "denies member" do
      sign_in member
      get "/pixel/new"

      expect(response).to redirect_to(root_path)
    end

    it "redirects to show if a pixel already exists" do
      create(:pixel, account: account)
      sign_in admin
      get "/pixel/new"

      expect(response).to redirect_to(pixel_path)
    end
  end

  describe "POST /pixel (create)" do
    def create_pixel(name: "My Landing Page", allowed_origins: "https://example.com")
      post "/pixel", params: { pixel: { name: name, allowed_origins: allowed_origins } }
    end

    it "lets account_admin create the account's pixel, generating a pixel_id server-side" do
      sign_in admin

      expect { create_pixel }.to change(Pixel, :count).by(1)

      pixel = account.reload.pixel
      expect(pixel.pixel_id).to match(/\Apx_[0-9a-f]+\z/)
      expect(pixel.allowed_origins).to eq([ "https://example.com" ])
      expect(response).to redirect_to(pixel_path)
    end

    it "parses multiple newline/comma separated origins" do
      sign_in admin
      create_pixel(allowed_origins: "https://a.example\nhttps://b.example, https://c.example")

      expect(account.reload.pixel.allowed_origins).to contain_exactly(
        "https://a.example", "https://b.example", "https://c.example"
      )
    end

    it "re-renders with real validation errors on a malformed origin" do
      sign_in admin
      create_pixel(allowed_origins: "not a url")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is not a valid http(s) origin")
      expect(Pixel.count).to eq(0)
    end

    it "denies member -- cannot create a pixel" do
      sign_in member

      expect { create_pixel }.not_to change(Pixel, :count)
      expect(response).to redirect_to(root_path)
    end

    it "denies super_admin -- cannot create a tenant's pixel" do
      sign_in create(:user, :super_admin)

      expect { create_pixel }.not_to change(Pixel, :count)
      expect(response).to redirect_to(root_path)
    end
  end
end
