class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_attributes, unless: :devise_controller?

  after_action :verify_pundit_authorization, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found, layout: "application" }
      format.any { head :not_found }
    end
  end

  def set_current_attributes
    Current.user = current_user
    Current.account = current_user.account
  end

  def after_sign_in_path_for(resource)
    resource.super_admin? ? admin_root_path : super
  end

  def user_not_authorized
    redirect_to root_path, alert: "You are not authorized to perform that action."
  end

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end
end
