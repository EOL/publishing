module MediaHelper
  def image_owner(image)
    image.owner.html_safe.sub(/^\(c\)\s+/i, "").sub(/^&copy;\s+/i, "").html_safe
  end

  def medium_not_in_collection_text(medium)
    t("content_not_in_any_collection_#{medium.subclass}") 
  end

  def medium_name_html(medium, page=nil)
    name = medium.name

    if name.blank?
      name = page ? 
        t("medium.untitled.#{medium.subclass}_of", page_name: page.name) :
        t("medium.untitled.#{medium.subclass}")
    end

    name.sub(/^File:/, "").sub(/\.\w{3,4}$/, "").html_safe
  end
end
