module PagesHelper
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

  def cached_summary(page)
    Rails.cache.fetch("brief_summary/#{page.id}") do
      BriefSummary.new(page).english # TODO: Someday we need to I18n this. ...somehow.
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

  def classification(this_node, ancestors, options = {})
    ancestors = Array(ancestors)
    return nil if ancestors.blank?
    node = ancestors.shift
    page = this_node.nil? ? @page : node.page
    haml_tag("div.item") do
      if (page.should_show_icon? && this_node && image = page.medium)
        haml_concat(image_tag(image.small_icon_url, alt: '', class: 'ui mini image'))
        haml_tag("div.content") do
          classification_content(page, this_node, node, ancestors)
        end
      else
        classification_content(page, this_node, node, ancestors)
      end
    end
  end

  def classification_content(page, this_node, node, ancestors)
    summarize(page, current_page: !this_node, node: node, no_icon: true)
    if ancestors.blank? && this_node
      haml_tag("div.ui.middle.aligned.list.descends") do
        classification(nil, [this_node])
        if this_node.children.any?
          haml_tag("div.item") do
            haml_tag("div.ui.middle.aligned.list.descends") do
              this_node.children.each do |child|
                haml_tag("div.item") do
                  if (child.page.should_show_icon? && this_node && image = child.page.medium)
                    haml_concat(image_tag(image.small_icon_url, alt: '', class: 'ui mini image'))
                    haml_tag("div.content") do
                      summarize(child.page, node: child, no_icon: true)
                    end
                  else
                    summarize(child.page, node: child, no_icon: true)
                  end
                end
              end
            end
          end
        end
      end
    else
      haml_tag("div.ui.middle.aligned.list.descends") do
        classification(this_node, ancestors)
      end
    end
  end

  def summarize(page, options = {})
    node = options[:node] || page.native_node || page.nodes.first
    page_id = page ? page.id : node.page_id
    name = options[:node] ? node.name : name_for_page(page)
    if options[:current_page]
      haml_tag("b") do
        haml_concat name.html_safe
      end
      haml_concat t("classifications.hierarchies.this_page")
    elsif (page && !options[:no_icon] && image = page.medium)
      haml_concat(image_tag(image.small_icon_url, class: 'ui mini image')) if page.should_show_icon?
    end
    haml_concat link_to(name.html_safe, page_id ? page_path(page_id) : "#")
    if page.nil?
      haml_tag("div.uk-padding-remove-horizontal.uk-text-muted") do
        haml_concat "PAGE MISSING (bad import)" # TODO: something more elegant.
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
    tl == 0 ? l : tl
  end

  private
    def hierarchy_helper(page, link, mode)
      parts = []
      node = page.native_node || page.nodes.first
      ancestors = node ? node.ancestors : []
      shown_ellipsis = false
      ancestors.compact.each do |anc_node|
        unless mode == :full || anc_node.use_breadcrumb?
          unless shown_ellipsis
            if link
              parts << content_tag(:span, "»", :class => "a js-show-full-hier")
            else
              parts << "»"
            end
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

      if mode == :full
        if link
          parts << content_tag(:span, "«", :class => "a js-show-summary-hier")
        else
          parts << "«"
        end
      end

      # surround / with zero-length spaces so text can wrap
      parts.join(" / ").html_safe
      #parts.join("&#8203;/&#8203;").html_safe
    end
end
