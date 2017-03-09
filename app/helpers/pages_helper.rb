module PagesHelper
  # Options: icon, count, path, name, active
  def tab(options)
    text = t("pages.tabs.#{options[:name]}")
    haml_tag("li", id: "page_nav_#{options[:name]}", class: options[:active] ? "uk-active" : nil, role: "presentation", title: text, uk: { tooltip: "delay: 100" } ) do
      haml_concat link_to("<span uk-icon='icon: #{options[:icon]}'></span>&emsp;<span class='uk-badge'>#{options[:count]}</span>".html_safe, options[:path], remote: true, class: "uk-hidden@m")
      haml_concat link_to("<div class='ui orange mini statistic'><div class='value'>#{options[:count]}</div><div class='label'>#{text}</div></div>".html_safe, options[:path], remote: true, class: "uk-visible@m")
      # Alt large version with floating number:
      # haml_concat link_to("<span class='uk-text-large'>#{text}</span><span class='floating ui tiny basic blue label'>#{options[:count]}</span>".html_safe, options[:path], remote: true, class: "uk-visible@m")
      # Alt version with icon:
      # haml_concat link_to("<span class='uk-text-large'><span uk-icon='icon: #{options[:icon]}'></span>&nbsp;#{text}</span><span class='floating ui tiny basic blue label'>#{options[:count]}</span>".html_safe, options[:path], remote: true, class: "uk-visible@m")
    end
  end

  def classification(this_node, ancestors)
    ancestors = Array(ancestors)
    return nil if ancestors.empty?
    node = ancestors.shift
    page = this_node.nil? ? @page : node.page
    vernacular = page.name if page
    names = vernacular && vernacular != node.canonical_form ? "#{vernacular} (#{node.canonical_form})" : node.canonical_form
    haml_tag("li") do
      haml_tag("div.uk-grid-collapse.uk-flex-middle", uk: {grid: true}) do
        haml_tag("div.uk-width-auto") do
          if page && page.icon
            haml_concat image_tag(page.icon, size: "40x40", class: "uk-margin-right")
          end
        end
        haml_tag("div.uk-width-expand") do
          haml_tag("h5.uk-header.uk-margin-remove") do
            if this_node
              haml_concat link_to(names.html_safe, node.page_id ? page_path(node.page_id) : "#")
            else
              haml_concat names.html_safe
              haml_concat t(:classification_list_this_page)
            end
            haml_tag("ul.uk-subnav.uk-subnav-divider.uk-margin-remove-top.uk-padding-remove-horizontal") do
              if page
                haml_tag("li.uk-padding-remove-horizontal") do
                  haml_concat "<span uk-icon='icon: image'></span>&ensp;<span class='uk-badge'>#{page.media_count}</span>".html_safe
                end
                haml_tag("li") do
                  haml_concat "<span uk-icon='icon: tag'></span>&ensp;<span class='uk-badge'>#{page.traits.size}</span>".html_safe
                end
                haml_tag("li") do
                  haml_concat "<span uk-icon='icon: social'></span>&ensp;<span class='uk-badge'>#{page.nodes.size}</span>".html_safe
                end
                haml_tag("li.uk-text-muted") do
                  haml_concat "etc..."
                end
              else
                haml_tag("li.uk-padding-remove-horizontal.uk-text-muted") do
                  haml_concat "PAGE MISSING (bad import)" # TODO: something more elegant.
                end
              end
            end
          end
        end
      end
      if ancestors.empty? && this_node
        haml_tag("ul.uk-list") do
          classification(nil, [this_node])
        end
      else
        haml_tag("ul.uk-list") do
          classification(this_node, ancestors)
        end
      end
    end
  end
end
