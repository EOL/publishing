module PagesHelper
  def classification(ancestors)
    ancestors = Array(ancestors)
    return if ancestors.empty?
    node = ancestors.shift
    haml_tag(".item") do
      if img = node.page.try(:icon)
        haml_concat(image_tag(img, class: "ui avatar image"))
      end
      haml_concat(link_to(node.canonical_form.html_safe, node.page_id ? page_path(node.page_id) : "#"))
      haml_tag(".list") do
        unless ancestors.empty?
          classification(ancestors)
        end
      end
    end
  end
end
