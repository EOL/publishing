module MediaHelper
  def image_owner(image)
    return '' if image.owner.blank?
    image.owner.html_safe.sub(/^\(c\)\s+/i, "").sub(/^&copy;\s+/i, "").html_safe
  end

  def medium_not_in_collection_text(medium)
    t("content_not_in_any_collection_#{medium.subclass}")
  end

  def medium_name_html(medium)
    name = medium.name

    if name.blank?
        name = medium.source_pages.any? ? 
          t("medium.untitled.#{medium.subclass}_of", page_name: medium.source_pages.first.name) :
          t("medium.untitled.#{medium.subclass}")
    end

    name.sub(/^File:/, "").sub(/\.\w{3,4}$/, "").html_safe
  end

  def medium_appears_on(medium)
    appears_on = []
    source_pages = medium.source_pages
    pages = medium.page_contents.map(&:page).compact.map do |page|
      [page.id, page]
    end.to_h
    
    source_pages.each do |source|
      node = source.safe_native_node
      ancestors = if node
                    node.node_ancestors.collect(&:ancestor).compact
                  else
                    []
                  end
      ancestors.each do |ancestor|
        page = pages.delete(ancestor.page&.id)
        appears_on << page if page
      end
    end

    appears_on
  end
end
