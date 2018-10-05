class PageIconPolicy < Struct.new(:user, :page_icon)
  def create?
    user && user.is_admin?
  end
end
