class CollectionSearchDecorator < NoHierSearchResultDecorator
  decorates :collection

  def icon
    nil
  end

  def fa_icon
    "folder-open-o"
  end

  def title
    name = object.try(:search_highlights).try(:[], :name) || object.name
    I18n.t("search_results.collection_title_html", :name => name)
  end

  def content
    if (!object.users.empty?)
      users_sentence = object.users.map do |u|
        u.username
      end.to_sentence
      I18n.t("search_results.collection_page_count_and_users", :count => object.pages.length,
        :users_sentence => users_sentence)
    else
      I18n.t("search_results.collection_page_count", :count => object.pages.length)
    end
  end

  def type
    :collections
  end

  def total_results
    object.response["hits"]["total"]
  end
end
