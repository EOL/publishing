class CollectionPolicy
  attr_reader :user, :collection

  def initialize(user, collection)
    @user = user
    @collection = collection
  end

  def update?
    user.is_admin? or collection.users.include?(user)
  end
end
