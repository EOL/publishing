module Publishing::GetsLanguages
  def get_language(hash)
    # Assumes that a given publishing run will have one language per group code
    @languages ||= {}
    return @languages[hash[:group_code]] if @languages.key?(hash[:group_code])

    locale = Locale.find_or_create_by(code: hash[:group_code])
    lang = locale.languages.where(code: hash[:code])

    if lang.nil?
      lang = Language.create!(locale: locale, code: hash[:code])
    end

    @languages[hash[:group_code]] = lang
    lang
  end
end
