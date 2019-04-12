class PageIconPolicy < Struct.new(:user, :page_icon)
  def create?
    user
  end
end
