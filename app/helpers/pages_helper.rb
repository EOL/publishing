module PagesHelper
  def construct_summary(page)
    Rails.cache.fetch("constructed_summary/#{page.id}") do
      ancestors = page.native_node.ancestors.select { |a| a.has_breadcrumb? }
      str = if page.name == page.scientific_name
        page.name
      else
        "#{page.scientific_name} (#{page.name})"
      end
      if ancestors[0]
        str += " #{page.scientific_name =~ /\s[a-z]/ ? "is" : "are" } #{indefinite_articleize(ancestors[0].name.singularize)}"
        if ancestors[-2]
          str += " in the #{ancestors[-2].rank.try(:name) || "clade"} #{ancestors[-2].scientific_name}."
        end
      else
        str += " is a top-level classification."
      end
      if page.is_it_extinct?
        str += " This species is extinct."
      end
      if page.is_it_marine?
        str += " It is marine."
      end
      unless page.habitats.empty?
        str += " It is found in #{page.habitats.split(", ").sort.to_sentence}."
      end
      bucket = page.id.to_s[0]
      summaries = Rails.cache.read("constructed_summaries/#{bucket}") || []
      summaries << page.id
      Rails.cache.write("constructed_summaries/#{bucket}", summaries)
      str.html_safe
    end
  end

  # Note: this does not always work (e.g.: "an unicorn")
  def indefinite_articleize(word)
    %w(a e i o u).include?(word[0].downcase) ? "an #{word}" : "a #{word}"
  end


  # Options: icon, count, path, name, active
  def tab(options)
    text = t("pages.tabs.#{options[:name]}")
    haml_tag("li", id: "page_nav_#{options[:name]}", class: options[:active] ? "uk-active" : nil, role: "presentation", title: text, uk: { tooltip: "delay: 100" } ) do
      haml_concat link_to("<span uk-icon='icon: #{options[:icon]}'></span>&emsp;<span class='uk-badge'>#{options[:count]}</span>".html_safe, options[:path], remote: true, class: "uk-hidden@m")
      haml_concat link_to("<div class='ui orange mini statistic'><div class='value'>#{options[:count]}</div><div class='label'>#{text}</div></div>".html_safe, options[:path], remote: true, class: "uk-visible@m")
    end
  end

  def classification(this_node, ancestors)
    ancestors = Array(ancestors)
    return nil if ancestors.empty?
    node = ancestors.shift
    page = this_node.nil? ? @page : node.page
    haml_tag("li.one") do
      summarize(page, current_page: ! this_node, node: node)
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

  def summarize(page, options = {})
    node = options[:node] || page.native_node
    page_id = page ? page.id : node.page_id
    vernacular = page.name.titleize if page
    icon_size = "tiny"
    names = vernacular && vernacular != node.canonical_form ? "#{vernacular} <span class='uk-text-muted uk-text-small'>#{node.canonical_form}</span>" : node.canonical_form
    haml_tag("span.#{icon_size}") do
      if options[:current_page]
        haml_concat names.html_safe
        haml_concat t(:classification_list_this_page)
      else
        haml_concat link_to(names.html_safe, page_id ? page_path(page_id) : "#")
      end
      haml_tag("div.uk-margin-remove-top.uk-padding-remove-horizontal") do
        if page
          if page.media_count > 0
            haml_tag("div.ui.#{icon_size}.label") do
              haml_concat "<i class='image icon'></i>#{page.media_count}".html_safe
            end
          end
          # haml_tag("div.ui.#{icon_size}.label") do
          #   haml_concat "<i class='tag icon'></i>#{page.traits.size}".html_safe
          # end
          # haml_tag("div.ui.#{icon_size}.label") do
          #   haml_concat "<i class='sitemap icon'></i>#{page.nodes.size}".html_safe
          # end
          # haml_tag("div.ui.#{icon_size}.label") do
          #   haml_concat "etc..."
          # end
        else
          haml_tag("div.uk-padding-remove-horizontal.uk-text-muted") do
            haml_concat "PAGE MISSING (bad import)" # TODO: something more elegant.
          end
        end
      end
    end
  end

  # TODO: we should really store the values like this! :S
  def unlink(text)
    return text.html_safe if text =~ /<a / # They already linked it.
    text.gsub(URI.regexp) { |match|
      if match.size < 20
        "<a href=\"#{match}\">#{match}</a>"
      else
        host = URI::parse(match).host
        "<a href=\"#{match}\">#{host}</a>"
      end
    }.html_safe
  end
end
