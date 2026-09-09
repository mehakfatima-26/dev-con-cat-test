class DashboardController < ApplicationController
  skip_after_action :verify_pundit_authorization

  def show
    redirect_to admin_root_path if Current.user.super_admin?
  end
end
