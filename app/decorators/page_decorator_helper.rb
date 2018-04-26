module PageDecoratorHelper
  def hierarchy
    parts = []
    node = object.native_node || object.nodes.first
    ancestors = node ? node.ancestors : []
    shown_ellipsis = false
    ancestors.compact.each do |anc_node|
      unless anc_node.use_breadcrumb?
        unless shown_ellipsis
          parts << "…"
          shown_ellipsis = true
        end
        next
      end

      parts << h.link_to(anc_node.canonical_form.html_safe, h.page_path(anc_node.page)).html_safe
      shown_ellipsis = false
    end

    parts.join("/").html_safe
  end
end
