module Names
  extend ActiveSupport::Concern
  
  included do
    has_many :preferred_vernaculars, -> { preferred }, class_name: "Vernacular"
  end
  
  def name(language = nil)
    language ||= Language.english
    vernacular(language).try(:string) || scientific_name
  end

  def vernacular(language = nil)
    language = Language.current || Language.english
    if preferred_vernaculars.loaded? || ! vernaculars.loaded?
      preferred_vernaculars.find { |v| v.language_id == language.id }
    else
      vernaculars.find { |v| v.language_id == language.id and v.is_preferred? }
    end
  end
end