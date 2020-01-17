# This overrides Refinery's monkey-patching with our own. Theirs always adds the locale, even if it's the default.
ApplicationController.class_eval do
  def default_url_options(options = {})
    locale = (I18n.locale == I18n.default_locale) ? nil : I18n.locale
    { locale: locale }.merge options
  end
end
