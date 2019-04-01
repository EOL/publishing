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
      hierarchy_pages = if node
                    node.node_ancestors.collect do |node_anc|
                      node_anc&.ancestor&.page
                    end.compact
                  else
                    []
                  end
      hierarchy_pages << source
      hierarchy_pages.each do |hierarchy_page|
        page = pages.delete(hierarchy_page&.id)
        appears_on << page if page
      end
    end

    appears_on
  end

  def media_thumbnail(medium) 
    if medium.sound? || medium.video?
      content_tag(:div, class: "grid-thumb grid-thumb-av") do
        content_tag(:i, "", class: "fa fa-5x fa-#{av_icon_name(medium)}") + 
        content_tag(:div, medium_name_html(medium))
      end
    else
      image_tag(medium&.medium_size_url, class: "grid-thumb")
    end
  end

  def media_image_or_player(medium, img_size)
    if medium.video?
      video_tag(medium&.base_url, type: "video/#{medium.format}", controls: true)
    else
      image_tag(medium&.send("#{img_size}_size_url"))
    end
  end

  private
  def av_icon_name(medium)
    if medium.sound?
      "volume-up"
    elsif medium.video?
      "video-camera"
    else
      raise "invalid medium type"
    end
  end
end
