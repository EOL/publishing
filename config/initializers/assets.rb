# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.

Rails.application.config.assets.precompile += %w( *.js application.css )
Rails.application.config.assets.precompile += %w( refinery/ckeditor.css )
Rails.application.config.assets.precompile += %w( ckeditor/ckeditor.js )

# For leaflet maps
%w( leaflet MarkerCluster MarkerCluster.Default Control.FullScreen Leaflet.NavBar Control.Loading ).each do |css_asset|
  Rails.application.config.assets.precompile << "#{css_asset}.css"
end

# TODO: remove last entry (should be dynamically loaded json)
%w( leaflet leaflet.markercluster Control.FullScreen Leaflet.NavBar freezable Control.Loading maps_leaflet 5169 ).each do |js_asset|
  Rails.application.config.assets.precompile << "#{js_asset}.js"
end

# controller-specific assets

%w( search pages terms home_page_feeds home_page_feed_items home_page media traits user/sessions users).each do |controller|
  Rails.application.config.assets.precompile += ["#{controller}.js", "#{controller}.css"]
end
