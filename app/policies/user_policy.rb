class UserPolicy
  attr_reader :user, :user_model

  def initialize(user, user_model)
    @user = user
    @user_model = user_model
  end

  def update?
    user && user.is_admin? or is_same_user?
  end

  def destroy?
    user && user.is_admin? or is_same_user?
  end

  def is_same_user?
    user.id == user_model.id
  end
end
