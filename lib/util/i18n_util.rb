class Util::I18nUtil
  RTL_LOCALES = Set.new([:ar]) # todo: move to config

  class << self
    def rtl?
      RTL_LOCALES.include? I18n.locale.to_sym
    end

    def non_default_locales
      I18n.available_locales.reject { |l| l == I18n.default_locale }
    end

    def term_name_property_for_locale(locale)
      if locale == I18n.default_locale
        "name" 
      else
        "name_#{locale.to_s.gsub("-", "_")}"
      end  
    end

    def term_name_property
      term_name_property_for_locale(I18n.locale)
    end
  end
end
