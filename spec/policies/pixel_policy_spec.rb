require "rails_helper"

RSpec.describe PixelPolicy do
  let(:account_a) { create(:account) }
  let(:account_b) { create(:account) }
  let(:pixel_a) { create(:pixel, account: account_a) }
  let(:pixel_b) { create(:pixel, account: account_b) }

  let(:admin_a) { create(:user, role: :account_admin, account: account_a) }
  let(:member_a) { create(:user, role: :member, account: account_a) }
  let(:super_admin) { create(:user, :super_admin) }

  describe "#show?" do
    it "allows account_admin and member to view their own account's pixel" do
      expect(described_class.new(admin_a, pixel_a)).to be_show
      expect(described_class.new(member_a, pixel_a)).to be_show
    end

    it "denies viewing another account's pixel" do
      expect(described_class.new(admin_a, pixel_b)).not_to be_show
      expect(described_class.new(member_a, pixel_b)).not_to be_show
    end

    it "allows a super_admin to view any account's pixel" do
      expect(described_class.new(super_admin, pixel_a)).to be_show
      expect(described_class.new(super_admin, pixel_b)).to be_show
    end
  end

  describe "#create?" do
    it "allows account_admin to create their own account's pixel" do
      expect(described_class.new(admin_a, pixel_a)).to be_create
    end

    it "denies member -- can view, cannot create" do
      expect(described_class.new(member_a, pixel_a)).not_to be_create
    end

    it "denies account_admin creating a pixel for another account" do
      expect(described_class.new(admin_a, pixel_b)).not_to be_create
    end

    it "denies super_admin -- pixel creation is tenant self-service, not a platform-operator power" do
      expect(described_class.new(super_admin, pixel_a)).not_to be_create
    end
  end
end
