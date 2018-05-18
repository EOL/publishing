module MediaHelper
  def image_owner(image)
    image.owner.html_safe.sub(/^\(c\)\s+/i, "").sub(/^&copy;\s+/i, "").html_safe
  end

  def medium_not_in_collection_text(medium)
    t("content_not_in_any_collection_#{medium.subclass}") 
  end
end
