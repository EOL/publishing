module PagesHelper
  def is_allowed_summary?(page)
    # TEMP: we're hacking this because we don't have ranks yet.
    return true
    page.rank && page.rank.respond_to?(:treat_as) &&
      ["r_species", "r_genus", "r_family"].include?(page.rank.treat_as)
  end

  def resource_names(page)
    page.resources.select do |r|
      r.name =~ /#{@q}/i
    end.uniq.map do |resource|
      n = emphasize_match(resource.name, @q)
      n += " (#{emphasize_match(resource.partner.short_name, @q)})".html_safe unless
        resource.name =~ /#{resource.partner.short_name}/
      n
    end
  end

  def vernacular_names(page)
    page.vernaculars.select do |pv|
      pv.string.downcase != page.name.downcase && pv.string =~ /#{@q}/i
    end.
      group_by(&:string).
      map do |string, names|
        (emphasize_match(string, @q) +
          "&nbsp;(#{names.map { |n| n.language.code }.uniq.join(", ")})".
          html_safe)
      end
  end

  def is_higher_level_clade?(page)
    page.rank && page.rank.respond_to?(:treat_as) &&
      ["r_genus", "r_family"].include?(page.rank.treat_as)
  end

  # TODO: it would be nice to make these into a module included by the Page
  # class.
  def is_family?(page)
    page.rank && page.rank.respond_to?(:treat_as) &&
      page.rank.treat_as == "r_family"
  end

  def is_genus?(page)
    page.rank && page.rank.respond_to?(:treat_as) &&
      page.rank.treat_as == "r_genus"
  end

  def nearest_landmark(page)
    return unless page.native_node
    page.ancestors.reverse.compact.find { |node| node.use_breadcrumb? }&.canonical_form
  end

  def construct_summary(page)
    # TEMP: return "" unless is_allowed_summary?(page)
    group = nearest_landmark(page)
    return "" unless group
    Rails.cache.fetch("constructed_summary/#{page.id}") do
      my_rank = page.rank.try(:name) || "taxon"
      node = page.native_node || page.nodes.first
      ancestors = node.ancestors.select { |a| a.has_breadcrumb? }
      # taxonomy sentence...
      str = if page.name == page.scientific_name
        page.name
      elsif page.scientific_name =~ /#{page.name}/
        # Sometimes the "name" is part of the scientific name, and it looks really weird to double up.
        page.scientific_name
      else
        "#{page.scientific_name} (#{page.name})"
      end
      # A1: There will be nodes in the dynamic hierarchy that will be flagged as
      # A1 taxa. If there are vernacularNames associated with the page of such a
      # taxon, use the preferred vernacularName. If not use the scientificName
      # from dynamic hierarchy. If the name starts with a vowel, it should be
      # preceded by an, if not it should be preceded by a.
      # A2: There will be nodes in the dynamic hierarchy that will be flagged as
      # A2 taxa. Use the scientificName from dynamic hierarchy.
      if true # TEMP fix for broken stuff below:
        str += " is in the group #{group}. "
      else # THIS STUFF BROKE WITH THE LATEST DYNAMIC HIERARCHY. We'll fix it later.
        if ancestors[0]
          if is_family?(page)
            # [name] ([common name]) is a family of [A1].
            str += " is #{a_or_an(my_rank)} of #{ancestors[0].name}."
          elsif is_higher_level_clade?(page) && ancestors[-2]
            # [name] ([common name]) is a genus in the [A1] [rank] [A2].
            str += " is #{a_or_an(my_rank)} in the #{ancestors[0].name} #{rank_or_clade(ancestors[-2])} #{ancestors[-2].scientific_name}."
          else
            # [name] ([common name]) is a[n] [A1] in the [rank] [A2].
            str += " #{is_or_are(page)} #{a_or_an(ancestors[0].name.singularize)}"
            if ancestors[-2] && ancestors[-2] != ancestors[0]
              str += " in the #{rank_or_clade(ancestors[-2])} #{ancestors[-2].scientific_name}"
            end
            str += "."
          end
        end
      end
      # Number of species sentence:
      if is_higher_level_clade?(page)
        count = page.species_count
        str += " It has #{count} species."
      end
      # Extinction status sentence:
      if page.is_it_extinct?
        str += " This #{my_rank} is extinct."
      end
      # Environment sentence:
      if ! is_higher_level_clade?(page) && page.is_it_marine?
        str += " It is marine."
      end
      # Distribution sentence:
      unless page.habitats.blank?
        str += " #{page.scientific_name} #{is_or_are(page)} found in #{page.habitats.split(", ").sort.to_sentence}."
        # TEMP: SKIP for now...
        # if is_family?(page)
        #   # Do nothing.
        # elsif is_genus?(page)
        #   str += " #{page.scientific_name} #{is_or_are(page)} found in #{page.habitats.split(", ").sort.to_sentence}."
        # else
        #   str += " It is found in #{page.habitats.split(", ").sort.to_sentence}."
        # end
      end
      bucket = page.id.to_s[0]
      summaries = Rails.cache.read("constructed_summaries/#{bucket}") || []
      summaries << page.id
      Rails.cache.write("constructed_summaries/#{bucket}", summaries)
      str.html_safe
    end
  end

  def rank_or_clade(node)
    node.rank.try(:name) || "clade"
  end

  def is_or_are(page)
    page.scientific_name =~ /\s[a-z]/ ? "is" : "are"
  end

  # Note: this does not always work (e.g.: "an unicorn")
  def a_or_an(word)
    %w(a e i o u).include?(word[0].downcase) ? "an #{word}" : "a #{word}"
  end

  # Options: icon, count, path, name, active
  def large_tab(options)
    text = t("pages.tabs.#{options[:name]}")
    active = options[:active] || current_page?(options[:path])
    haml_tag("li", class: "#{options[:name]} #{active ? "uk-active" : nil}", role: "presentation", title: text, uk: { tooltip: "delay: 100" } ) do
      haml_concat link_to("<div class='ui orange mini statistic'><div class='value'>#{options[:count] || "&nbsp;".html_safe}</div><div class='label'>#{text}</div></div>".html_safe, options[:path], remote: true)
    end
  end

  def small_tab(options)
    text = t("pages.tabs.#{options[:name]}")
    active = options[:active] || current_page?(options[:path])
    mobile_link = "<i class='icon #{options[:icon]}'></i>"
    haml_concat link_to("#{mobile_link} #{text}".html_safe, options[:path], remote: true, class: "#{options[:name]} #{active ? "active " : "" }item")
  end

  def index_stat(key, count)
    return '0' if count.nil?
    count =
      if count > 1_000_000
        "#{(count / 100_000) / 1.0}M"
      elsif count > 10_000
        "#{(count / 1_000) / 1.0}K"
      else
        number_with_delimiter(count)
      end
    haml_tag("div.ui.orange.statistic") do
      haml_tag("div.value") { haml_concat count }
      haml_tag("div.label") { haml_concat t("stats.#{key}") }
    end
  end

  def classification(this_node, ancestors, options = {})
    ancestors = Array(ancestors)
    return nil if ancestors.blank?
    node = ancestors.shift
    page = this_node.nil? ? @page : node.page
    haml_tag("li.one") do
      summarize(page, current_page: ! this_node, node: node)
      if ancestors.blank? && this_node
        haml_tag("ul.uk-list.descends") do
          classification(nil, [this_node])
          if this_node.children.any?
            haml_tag("ul.uk-list.descends") do
              this_node.children.each do |child|
                haml_tag("li.one") do
                  summarize(child.page, node: child)
                end
              end
            end
          end
        end
      else
        haml_tag("ul.uk-list.descends") do
          classification(this_node, ancestors)
        end
      end
    end
  end

  def summarize(page, options = {})
    node = options[:node] || page.native_node || page.nodes.first
    page_id = page ? page.id : node.page_id
    name = options[:node] ? node.name : name_for_page(page)
    haml_tag("span.tiny") do
      if options[:current_page]
        haml_tag("b") do
          haml_concat name.html_safe
        end
        haml_concat t("classifications.hierarchies.this_page")
      elsif page
        show_data_page_icon(page) if page.should_show_icon?
        haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : "#")
      end
      haml_tag("div.uk-margin-remove-top.uk-padding-remove-horizontal") do
        if page.nil?
          haml_tag("div.uk-padding-remove-horizontal.uk-text-muted") do
            haml_concat "PAGE MISSING (bad import)" # TODO: something more elegant.
          end
        end
      end
    end
  end

  def tab(name_key, path)
    haml_tag(:li, :class => "tab #{(current_page?(path) ? "is-tab-selected" : "")}") do
      haml_concat link_to(name_key, path)
    end
  end

  # TODO: we should really store the values like this! :S
  def unlink(text)
    return text.html_safe if text =~ /<a / # They already linked it.
    text.gsub(URI::ABS_URI) { |match|
      if match.size < 20
        "<a href=\"#{match}\">#{match}</a>"
      else
        host = URI::parse(match).host
        "<a href=\"#{match}\">#{host}</a>"
      end
    }.html_safe
  end

  def overview?
    current_page?(page_path(@page))
  end

  def hierarchy(page, link)
    parts = []
    node = page.native_node || page.nodes.first
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

      if link
        parts << link_to(anc_node.canonical_form.html_safe, page_path(anc_node.page)).html_safe
      else
        parts << anc_node.canonical_form.html_safe
      end

      shown_ellipsis = false
    end

    parts.join("/").html_safe
  end
end
