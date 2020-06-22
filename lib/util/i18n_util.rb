class Util::I18nUtil
  RTL_LOCALES = Set.new([:ar]) # todo: move to config

  class << self
    def rtl?
      RTL_LOCALES.include? I18n.locale.to_sym
    end
  end
end
