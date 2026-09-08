class PixelPolicy < ApplicationPolicy
  def create?
    user.account_admin? && record.account_id == user.account_id
  end
end
