require "refinery"

# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://eol.org"
SitemapGenerator::Sitemap.sitemaps_path = "data/sitemap"

SitemapGenerator::Sitemap.create do
  def add_custom(path)
    add path, lastmod: nil, priority: nil, changefreq: nil
  end

  # /terms/search
  add_custom term_search_path
  
  # CMS Pages
  ::I18n.available_locales.each do |locale|
    ::I18n.locale = locale
    ::Refinery::Page.live.in_menu.each do |cms_page|
      cms_url = if cms_page.url.is_a?(Hash)
                  cms_url = ::Refinery::Core::Engine.routes.url_for(cms_page.url.merge(only_path: true))
                else
                  cms_url = cms_page.url
                end

      add_custom cms_url
    end
  end

  ::I18n.locale = ::I18n.default_locale

  # Pages
  Page.find_each do |page|
    add_custom page_path(page)
    add_custom page_data_path(page) if page.has_data?
    add_custom page_maps_path(page) if page.map?
    add_custom page_media_path(page) if page.media_count > 0
    add_custom page_articles_path(page) if page.articles_count > 0
    add_custom page_names_path(page)
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
