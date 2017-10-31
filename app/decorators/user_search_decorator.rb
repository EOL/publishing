class UserSearchDecorator < Draper::Decorator
  decorates :user
  delegate :persisted?

  def self.collection_decorator_class
    SearchResultsDecorator
  end

  def type
    :users
  end

  def icon
    nil
  end

  def fa_icon
    "user-o"
  end

  def title
    name = object.try(:search_highlights).try(:[], :username) || object.username
    I18n.t("search_results.user_title_html", :name => name.html_safe)
  end

  def content
    object.try(:search_highlights).try(:[], :bio) || object.bio || ""
  end

  def misc_info
    ""
  end

end

