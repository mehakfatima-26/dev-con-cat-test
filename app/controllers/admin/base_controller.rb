module Admin
  class BaseController < ApplicationController
    before_action :require_super_admin

    private

    def require_super_admin
      raise Pundit::NotAuthorizedError unless current_user.super_admin?
    end
  end
end
