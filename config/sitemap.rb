require "refinery"

# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://eol.org"
SitemapGenerator::Sitemap.sitemaps_path = "data/sitemap"

SitemapGenerator::Sitemap.create do
  def add_custom(path, alternates = [])
    add path, lastmod: nil, priority: nil, changefreq: nil, alternates: alternates
  end

  ::I18n.locale = ::I18n.default_locale

  # /terms/search
  add_custom term_search_path
  
  # CMS Pages

  EditorPage.find_each do |page|
    if page.published_for_locale(::I18n.default_locale).present?
      # TODO: figure out how to get absolute urls in alternates -- possible bug with SitemapGenerator
      #alternates = ::I18n.available_locales.collect do |locale|
      #  next if locale == I18n.default_locale
      #  if page.published_for_locale(locale).present?
      #    { 
      #      href: editor_page_path(id: page.name, directory_id: page&.editor_page_directory&.name, locale: locale),
      #      lang: locale
      #    }
      #  else
      #    nil
      #  end
      #end.compact

      add_custom(editor_page_path(id: page.name, directory_id: page&.editor_page_directory&.name, locale: nil))
    end
  end


  # Pages
  Page.find_each do |page|
    if page.has_data?
      add_custom page_path(page, locale: nil)
      add_custom page_data_path(page, locale: nil)
      add_custom page_maps_path(page, locale: nil) if page.map?
      add_custom page_media_path(page, locale: nil) if page.media_count > 0
      add_custom page_articles_path(page, locale: nil) if page.articles_count > 0
      add_custom page_names_path(page, locale: nil)
    end
  end
  
  ####################################
  # Instructions from generated file #
  ####################################
  #
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly',
  #           :lastmod => Time.now, :host => default_host
  #
  # Examples:
  #
  # Add '/articles'
  #
  #   add articles_path, :priority => 0.7, :changefreq => 'daily'
  #
  # Add all articles:
  #
  #   Article.find_each do |article|
  #     add article_path(article), :lastmod => article.updated_at
  #   end
end
