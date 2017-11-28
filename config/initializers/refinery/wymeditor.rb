# encoding: utf-8
Refinery::Wymeditor.configure do |config|
  # Add extra tags to the wymeditor whitelist e.g. = {'a' => {'attributes': '1': 'href'}} or just {'a' => {}}
  config.whitelist_tags = { 'iframe' => {} }

  # Toggle the paste dialog when using browser paste.
  # You will have to clear your asset cache after changing this setting.
  # In development mode: this is as simple as: `rm -rf tmp/cache/assets`.
  # In production mode: hopefully you recompile assets every time you deploy.
  # config.intercept_paste = true
end
