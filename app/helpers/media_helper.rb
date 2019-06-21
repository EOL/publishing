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
    if medium.sound? || medium.embedded_video?
      content_tag(:div, class: "grid-thumb grid-thumb-av") do
        content_tag(:i, "", class: "fa fa-5x fa-#{av_icon_name(medium)}") +
        content_tag(:div, medium_name_html(medium))
      end
    elsif medium.video?
      content_tag(:div, class: "grid-thumb grid-thumb-av grid-thumb-av-video") do
        video_tag(medium&.url_with_format, type: "video/#{medium.format}", controls: false) +
        content_tag(:i, "", class: "fa fa-5x fa-#{av_icon_name(medium)}")
      end
    else
      image_tag(medium&.medium_size_url)
    end
  end

  def media_image_or_player(medium, img_size)
    if medium.embedded_video?
      content_tag(:iframe, nil, src: medium.embed_url, width: 426, height: 240, class: "js-#{medium.format}-player")
    elsif medium.video?
      video_tag(medium&.url_with_format, type: "video/#{medium.format}", controls: true)
    elsif medium.sound?
      audio_tag(medium&.url_with_format, controls: true, class: "gallery-audio-player")
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
