# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = ENV.fetch('EOL_PUBLISHING_URL') { 'https://eol.org' }
SitemapGenerator::Sitemap.sitemaps_path = "data/sitemap"

SitemapGenerator::Sitemap.create do
  # Empty, for now.
end
