class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    same_account?
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  private

  def same_account?
    user.super_admin? || record.account_id == user.account_id
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user.super_admin? ? scope.all : scope.where(account_id: user.account_id)
    end
  end
end
