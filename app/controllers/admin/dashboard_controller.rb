module Admin
  class DashboardController < Admin::BaseController
    skip_after_action :verify_pundit_authorization

    def show
      @accounts = Account.all.sort_by { |account| [ account.at_risk? ? 0 : 1, account.days_to_zero ] }
    end
  end
end
