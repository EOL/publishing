module CollectionsHelper
  def remove_collection_user_link(collection, user)
    link_to("<i class='ui trash outline icon'></i>".html_safe, collection_remove_user_path(collection, user_id: user.id), method: "post", remote: true)
  end
end
