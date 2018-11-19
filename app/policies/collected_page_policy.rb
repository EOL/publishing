class CollectedPagePolicy
  attr_reader :user, :collection

  def initialize(user, collected_page)
    @user = user
    @collected_page = collected_page
  end

  def create?
    user && user.is_admin? or collected_page.collection.users.include?(user)
  end

  def update?
    user && user.is_admin? or collected_page.collection.users.include?(user)
  end

  def destroy?
    user && user.is_admin? or collected_page.collection.users.include?(user)
  end

  def add_user?
    user && user.is_admin? or collected_page.collection.users.include?(user)
  end

  def remove_user?
    user && user.is_admin? or collected_page.collection.users.include?(user)
  end
end
