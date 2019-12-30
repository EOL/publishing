class TermNames::NameStorage
  def initialize
    @by_locale = {}
  end

  def set_value_for_locale(locale, uri, value)
    values_for_locale(locale)[uri] = value
  end

  def values_for_locale(locale)
    @by_locale[locale] ||= {}
    @by_locale[locale]
  end 

  def names_for_locale(locale)
    raw_result = values_for_locale(locale)
    raw_result.collect do |k,v|
      TermNames::Result.new(k, v)
    end
  end
end
