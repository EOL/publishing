module PagesHelper
  RecordsPerPred = 5

  def records_per_pred
    RecordsPerPred
  end

  def is_allowed_summary?(page)
    # TEMP: we're hacking this because we don't have (enough) ranks yet.
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

  def classification(node)
    ancestors = Array(node.ancestors.compact)
    ancestors.push(node)
    classification_helper(node, ancestors)
  end

  def classification_helper(this_node, ancestors)
    raise TypeError.new("ancestors can't be empty") if ancestors.empty?
    node = ancestors.shift
    page = node.page
    classification_content(page, this_node, node, ancestors)
  end

  def classification_content(page, this_node, node, ancestors)
    # have to capture this state here, because it will always be empty where we need the check
    show_siblings = ancestors.empty?

    haml_tag("div.item") do
      summarize(page, name: node.scientific_name, current_page: node == this_node, node: node, no_icon: true)
      if ancestors.empty?
        if this_node.children.any?
          haml_tag("div.item") do
            haml_tag("div.ui.middle.aligned.list.descends") do
              # sanitize so <i> tags aren't counted for sorting purposes
              sort_nodes_by_name(this_node.children).each do |child|
                haml_tag("div.item") do
                  summarize(child.page, name: child.scientific_name, node: child, no_icon: true)
                end
              end
            end
          end
        end
      else
        haml_tag("div.ui.middle.aligned.list.descends") do
          classification_helper(this_node, ancestors)
        end
      end
    end

    if show_siblings && this_node.siblings && this_node.siblings.size > 0
      sort_nodes_by_name(this_node.siblings[0..99]).each do |sibling|
        haml_tag("div.item") do
          summarize(sibling.page, name: sibling.scientific_name, current_page: false, node: sibling, no_icon: true)
        end
      end
      if this_node.siblings.size > 100
        haml_tag("div.item") do
          haml_concat t('classifications.hierarchies.truncated_siblings', count: this_node.siblings.size - 100)
        end
        haml_tag("div.item") do
          link = "#{Rails.application.secrets.repository['url']}/resources/#{this_node.resource.repository_id}"
          haml_concat t('classifications.hierarchies.see_resource_file', href: link).html_safe
        end
      end
    end
  end

  def summarize(page, options = {})
    page_id = if page
                page.id
              elsif options[:node]
                options[:node].page_id
              else
                nil
              end
    return('[unknown page]') if page_id.nil?
    name = options[:name]
    if options[:current_page]
      haml_tag('b') do
        haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : '#')
      end
      haml_concat t('classifications.hierarchies.this_page')
    elsif (page && !options[:no_icon] && image = page.medium)
      haml_concat(image_tag(image.small_icon_url, class: 'ui mini image')) if page.should_show_icon?
      haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : '#')
    else
      haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : '#')
    end
    if page.nil?
      haml_tag('div.uk-padding-remove-horizontal.uk-text-muted') do
        haml_concat 'PAGE MISSING (bad import)' # TODO: something more elegant.
      end
    end
  end

  def tab(name_key, path)
    haml_tag(:li, :class => "tab #{(current_page?(path) ? "is-tab-selected" : "")}") do
      haml_concat link_to(t("pages.tabs.#{name_key}"), path)
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

  def summary_hierarchy(page, link)
    hierarchy_helper(page, link, :partial)
  end

  def full_hierarchy(page, link)
    hierarchy_helper(page, link, :full)
  end

  def language_header(l)
    return t("languages.none") if l.blank?
    tl = t("languages.#{l}")
    return l if tl =~ /^translation missing/
    return l if tl =~ /^I18n:/
    tl == 0 ? l : tl
  end

  def show_page_media_filters?(filterable)
    filterable && (
      (@license_groups && @license_groups.length > 1) ||
      (@resources && @resources.length > 1)
    )
  end

  def sorted_grouped_vernaculars(page)
    grouped_vernaculars = page.vernaculars.group_by { |n| n.language.group }
    cur_lang_group = Language.current.group
    sorted_keys = grouped_vernaculars.keys.sort do |a, b|
      if a == cur_lang_group && b != cur_lang_group
        -1
      elsif a != cur_lang_group && b == cur_lang_group
        1
      else
        # TODO: this is inefficient! Find a better way. Instantiates view context per call.
        language_header(a) <=> language_header(b)
      end
    end

    sorted_keys.collect do |key|
      {
        lang: key,
        vernaculars: grouped_vernaculars[key]
      }
    end
  end

  def group_sort_names_for_card(names, include_rank, include_status)
    result = names.group_by do |n|
      rank = n.node.rank
      status = n.taxonomic_status&.name
      dwh_str = n.resource&.dwh? ? "a" : "b"
      key = "#{dwh_str}.#{n.italicized}"
      key += ".#{rank.treat_as}" if include_rank && rank
      key += ".#{status}" if include_status && status
      key
    end.values.sort_by do |v|
      first = v.first
      dwh_part = first.resource&.dwh? ? "a" : "b"
      rank_part = include_rank && first.node&.has_rank_treat_as? ? I18n.t("pages.resource_names.rank.#{first.node.rank_treat_as}") : "zzz"
      # TODO: Update once taxonomic statuses are i18n-able
      status_part = include_status && first.taxonomic_status&.name ? first.taxonomic_status&.name : "zzz"
      [dwh_part, (first.italicized || "(missing italicized form)"), rank_part, status_part]
    end
  end

private

  def hierarchy_helper(page, link, mode)
    Rails.cache.fetch("pages/hierarchy_helper/#{page.id}/link_#{link}/#{mode || :none}/#{I18n.locale}/#{breadcrumb_type}", expires_in: 1.day) do
      name_method = breadcrumb_type == BreadcrumbType.vernacular ? :vernacular_or_canonical : :canonical
      parts = []
      node = page.safe_native_node
      ancestors = if node
                    if node.node_ancestors.loaded?
                      node.node_ancestors.collect(&:ancestor).compact
                    else
                      Rails.logger.warn('INEFFICIENT LOAD OF PAGE ANCESTORS FOR #hierarchy_helper')
                      node.node_ancestors.
                        includes(ancestor: { page: [:preferred_vernaculars, { native_node: :scientific_names }] }).
                        collect(&:ancestor).compact
                    end
                  else
                    []
                  end
      shown_ellipsis = false
      unresolved = ancestors.any? && ancestors.none? { |anc| anc.use_breadcrumb? }

      if mode == :partial && unresolved
        parts << content_tag(:span, t("pages.unresolved_name"), class: "a js-show-full-hier")
      else
        ancestors.compact.each do |anc_node|
          anc_page = anc_node.page
          if anc_node.use_breadcrumb? || mode == :full
            if link
              parts << link_to(anc_page.send(name_method).html_safe, page_path(anc_page)).html_safe
            else
              parts << anc_page.send(name_method).html_safe
            end
            shown_ellipsis = false
          elsif !shown_ellipsis
            if link
              parts << content_tag(:span, "…", class: "a js-show-full-hier")
            else
              parts << "…"
            end
            shown_ellipsis = true
          end
        end
      end

      result = parts.join(" » ").html_safe

      if mode == :full
        final_parts = []

        if unresolved
          final_parts << t("pages.unresolved_name_prefix")
        end

        final_parts << result

        if link
          final_parts << content_tag(:span, "«", class: "a js-show-summary-hier")
        end

        result = final_parts.join(" ")
      end

      result
    end
  end

  def sort_by_name_for_page(pages)
    pages.sort do |a, b|
      # sanitize so <i> tags aren't counted for sorting purposes
      a_name = sanitize(name_for_page(a), tags: [])
      b_name = sanitize(name_for_page(b), tags: [])

      a_name <=> b_name
    end
  end

  def page_resource_names_link(name, include_remarks)
    if name.resource.dwh? && name.attribution.present?
      if include_remarks && name.remarks.present?
        I18n.t(
          "pages.resource_names.resource_link_w_remarks_attribution_html",
          resource_path: resource_path(name.resource),
          resource_name: name.resource.name,
          remarks: name.remarks,
          attribution: name.attribution.html_safe
        )
      else
        I18n.t(
          "pages.resource_names.resource_link_w_attribution_html",
          resource_path: resource_path(name.resource),
          resource_name: name.resource.name,
          attribution: name.attribution.html_safe
        )
      end
    else
      if include_remarks && name.remarks.present?
        I18n.t(
          "pages.resource_names.resource_link_w_remarks_html",
          resource_path: resource_path(name.resource),
          resource_name: name.resource.name,
          remarks: name.remarks
        )
      else
        I18n.t(
          "pages.resource_names.resource_link_html",
          resource_path: resource_path(name.resource),
          resource_name: name.resource.name
        )
      end
    end
  end

  private
    def sort_nodes_by_name(nodes)
      nodes.sort do |a, b|
        a_name = sanitize(a.name, tags: [])
        b_name = sanitize(b.name, tags: [])

        a_name <=> b_name
      end
    end
end
