module Publishing::GetsLanguages
  def get_language(hash)
    @languages ||= {}
    return @languages[hash[:group_code]] if @languages.key?(hash[:group_code])
    lang = Language.where(group: hash[:group_code]).first_or_create do |l|
      l.group = hash[:group_code]
      l.code = hash[:code]
    end
    @languages[hash[:group_code]] = lang.id
  end
end
