module PagesHelper
  def is_allowed_summary?(page)
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

  def construct_summary(page)
    return "" unless is_allowed_summary?(page)
    Rails.cache.fetch("constructed_summary/#{page.id}") do
      my_rank = page.rank.try(:name) || "taxon"
      node = page.native_node || page.nodes.first
      ancestors = node.ancestors.select { |a| a.has_breadcrumb? }
      # taxonomy sentence...
      str = if page.name == page.scientific_name
        page.name
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
        if is_family?(page)
          # Do nothing.
        elsif is_genus?(page)
          str += " #{page.scientific_name} #{is_or_are(page)} found in #{page.habitats.split(", ").sort.to_sentence}."
        else
          str += " It is found in #{page.habitats.split(", ").sort.to_sentence}."
        end
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
    count = count > 1_000_000 ? "#{(count / 100_000) / 10.0}M" :
      number_with_delimiter(count)
    haml_tag("div.ui.orange.statistic") do
      haml_tag("div.value") { haml_concat count }
      haml_tag("div.label") { haml_concat t("landing_page.stats.#{key}") }
    end
  end

  def classification(this_node, ancestors)
    ancestors = Array(ancestors)
    return nil if ancestors.blank?
    node = ancestors.shift
    page = this_node.nil? ? @page : node.page
    haml_tag("li.one") do
      summarize(page, current_page: ! this_node, node: node)
      if ancestors.blank? && this_node
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
    node = options[:node] || page.native_node || page.nodes.first
    page_id = page ? page.id : node.page_id
    vernacular = page.name.titleize if page
    icon_size = "tiny"
    names = vernacular && vernacular != node.canonical_form ? "#{vernacular} <span class='uk-text-muted uk-text-small'>#{node.canonical_form}</span>" : node.canonical_form
    haml_tag("span.#{icon_size}") do
      if options[:current_page]
        haml_concat names.html_safe
        haml_concat t("classifications.hierarchies.this_page")
      elsif page
        show_data_page_icon(page) if page.should_show_icon?
        haml_concat link_to(names.html_safe, page_id ? page_path(page_id) : "#")
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
