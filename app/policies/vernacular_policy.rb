class VernacularPolicy
  attr_reader :user, :vernacular

  def initialize(user, vernacular)
    @user = user
    @vernacular = vernacular
  end

  def update?
    user #&& user.is_power_user?
  end

  def destroy?
    user && user.is_admin?
  end
end
