module EolSpecHelpers
  def another_language
    Language.where(group: "de").first_or_create do |l|
      l.code = "deu"; l.group = "de"
    end
  end
end
