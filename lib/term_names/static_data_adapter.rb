class TermNames::StaticDataAdapter
  FILE_NAMES = %w(obo_terms common_predicates common_envo)
  FILE_PATHS = FILE_NAMES.collect do |name|
    Rails.application.root.join("lib", "term_names", "static_data", "#{name}.json")
  end

  def self.name
    "static_data"
  end

  def skip_uri_query?
    true
  end

  def include_default_locale?
    true
  end

  def preload(uris, locales)
    @terms = []

    FILE_PATHS.each do |path|
      File.open(path) do |file|
        term_json = JSON.parse(file.read)
        @terms += term_json["data"].collect do |record|
          TermNames::Result.new(record[0], record[1])
        end
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
