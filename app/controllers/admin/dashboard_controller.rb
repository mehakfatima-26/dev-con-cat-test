module Admin
  class DashboardController < Admin::BaseController
    skip_after_action :verify_pundit_authorization

    def show
    end
  end
end
