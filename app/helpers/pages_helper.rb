module PagesHelper
  def classification(ancestors)
    ancestors = Array(ancestors)
    return if ancestors.empty?
    node = ancestors.shift
    haml_tag(".item") do
      img = node.page.try(:icon)
      if img
        haml_concat(image_tag(img, class: "ui avatar image"))
      end
      has_name = node.page.try(:name)
      segments = []
      if img
        segments << image_tag(img, class: "ui image")
      end
      if node.page
        segments << node.page.name.html_safe
        segments << "<div class='ui circular small blue label'>#{node.page.media_count}</div> <div class='ui circular olive label'>#{node.page.nodes.count}</div></div>"
      else
        segments << "PAGE INCOMPLETE!"
      end
      html = "<div class='ui segments'><div class='ui segment inverted'>#{segments.join("</div><div class='ui inverted segment'>")}</div></div>"
      haml_concat(link_to(node.canonical_form.html_safe, node.page_id ? page_path(node.page_id) : "#", data: { html: html, variation: "inverted" }, class: "pops up"))
      haml_tag(".list") do
        unless ancestors.empty?
          classification(ancestors)
        end
      end
    end
  end
end
