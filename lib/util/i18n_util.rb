class Util::I18nUtil
  RTL_LOCALES = Set.new([:ar]) # todo: move to config

  class << self
    def rtl?
      RTL_LOCALES.include? I18n.locale.to_sym
    end

    def non_default_locales
      I18n.available_locales.reject { |l| l == I18n.default_locale }
    end
  end
end
