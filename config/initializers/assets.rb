# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
# NOTE: commented out because it was causing errors about missing coffeescript support and making initial requests
# extremely slow after server reboot. If you want to include a specific package from node_node modules, do that, but
# don't add the whole thing.
# Rails.application.config.assets.paths << Rails.root.join('node_modules') 

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w( *.js application.css )

%w( leaflet MarkerCluster MarkerCluster.Default Control.FullScreen Leaflet.NavBar Control.Loading jqcloud).each do |css_asset|
  Rails.application.config.assets.precompile << "#{css_asset}.css"
end

%w( leaflet leaflet.markercluster Control.FullScreen Leaflet.NavBar freezable Control.Loading maps_leaflet 5169 jqcloud).each do          |js_asset|
  Rails.application.config.assets.precompile << "#{js_asset}.js"
end

# controller-specific assets:
# TODO: remove 'about', only there for sankey test page
%w( about search pages terms home_page_feeds home_page_feed_items home_page media traits user/sessions users collections about traits/data_viz editor_pages admin/editor_pages admin/editor_page_contents ).each do |controller|
  Rails.application.config.assets.precompile += ["#{controller}.js", "#{controller}.css"]
end

