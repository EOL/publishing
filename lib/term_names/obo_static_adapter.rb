
class TermNames::OboStaticAdapter
  FILE_PATH = Rails.application.root.join("lib", "term_names", "static_data", "obo_terms.json")

  def self.name
    "obo_static"
  end

  def skip_uri_query?
    true
  end

  def include_default_locale?
    true
  end

  def preload(uris, locales)
    File.open(FILE_PATH) do |file|
      term_json = JSON.parse(file.read)
      @terms = term_json["data"].collect do |record|
        TermNames::Result.new(record[0], record[1])
      end
    end
  end

  def names_for_locale(locale)
    if locale.to_sym == :en
      @terms
    else
      []
    end
  end
end
