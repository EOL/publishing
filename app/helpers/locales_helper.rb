module LocalesHelper
  def locale_nil_default
    I18n.locale == I18n.default_locale ? nil : I18n.locale
  end
end
