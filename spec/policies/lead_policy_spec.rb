require "rails_helper"

RSpec.describe LeadPolicy do
  let(:account_a) { create(:account) }
  let(:account_b) { create(:account) }
  let(:lead_a) { create(:lead, pixel: create(:pixel, account: account_a), account: account_a) }
  let(:lead_b) { create(:lead, pixel: create(:pixel, account: account_b), account: account_b) }

  let(:member_a) { create(:user, role: :member, account: account_a) }
  let(:super_admin) { create(:user, :super_admin) }

  describe "#show?" do
    it "allows a user to view a lead belonging to their own account" do
      expect(described_class.new(member_a, lead_a)).to be_show
    end

    it "denies a user viewing another account's lead" do
      expect(described_class.new(member_a, lead_b)).not_to be_show
    end

    it "allows a super_admin to view any account's lead" do
      expect(described_class.new(super_admin, lead_a)).to be_show
      expect(described_class.new(super_admin, lead_b)).to be_show
    end
  end

  describe "Scope" do
    it "resolves to only the user's own account's leads" do
      lead_a
      lead_b

      resolved = LeadPolicy::Scope.new(member_a, Lead).resolve

      expect(resolved).to contain_exactly(lead_a)
    end

    it "resolves to every account's leads for a super_admin" do
      lead_a
      lead_b

      resolved = LeadPolicy::Scope.new(super_admin, Lead).resolve

      expect(resolved).to contain_exactly(lead_a, lead_b)
    end
  end
end
