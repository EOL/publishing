module HasVernaculars
  extend ActiveSupport::Concern

  def vernacular(languages = nil)
    languages ||= Language.english

    if preferred_vernaculars.loaded?
      Language.first_matching_record(languages, preferred_vernaculars)
    else
      if vernaculars.loaded?
        Language.all_matching_records(languages, vernaculars).find { |v| v.is_preferred? }
      else
        # I don't trust the associations. :|
        Vernacular.where(node_id: id, language: languages).preferred.first
      end
    end
  end
end
