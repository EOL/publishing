require "util/term_i18n"
require "fileutils"

class TermNames
  ADAPTERS = [TermNames::GeonamesAdapter, TermNames::WikidataAdapter]
  ADAPTERS_BY_NAME = ADAPTERS.collect { |a| [a.name, a] }.to_h
  LOCALE_FILE_DIR = Rails.application.root.join("config", "locales", "terms")
  TERM_LIMIT = 1500 # XXX: arbitrary limit based on Jen's estimates. Revisit as necessary.

  class << self
    def refresh(adapter_name)
      if adapter_name
        user_adapter_class = ADAPTERS_BY_NAME[adapter_name]
        raise TypeError.new("Invalid provider name: #{adapter_name}") unless user_adapter_class
        adapters = [user_adapter_class]
      else
        adapters = ADAPTERS
      end

      adapters.each do |adapter_class|
        adapter = adapter_class.new
        puts "Querying uris for adapter #{adapter_class.name}"
        uris = self.term_uris_for_adapter(adapter)
        puts "Got #{uris.length} results"
        puts "Preloading..."
        adapter.preload(uris, I18n.available_locales)
        puts "Done preloading"
        
        I18n.available_locales.reject { |l| l == I18n.default_locale }.each do |locale|
          puts "Getting results for locale #{locale}"
          results = adapter.names_for_locale(locale)

          writable_entries = results.collect do |result|
            [TermI18n.uri_to_key(result.uri), result.value]
          end.to_h

          if writable_entries.any?
            file_name = "#{adapter_class.name.downcase}.#{locale}.yml"
            bak_name = "#{adapter_class.name.downcase}.#{locale}.yml.bak"
            file_path = LOCALE_FILE_DIR.join(file_name)
            bak_path = LOCALE_FILE_DIR.join(bak_name)

            self.backup_file(file_path, bak_path)
            puts "Writing results for locale #{locale} to #{file_path}"
            File.open(file_path, "w") do |file|
              file.write({
                locale.to_s => { 
                  "term": { 
                    "name": { 
                      "by_uri": writable_entries
                    }
                  }
                }
              }.to_yaml)
            end
          else
            puts "No results found for locale #{locale}. Not writing locale file."
          end
        end
      end

      puts "Done! Inspect the results, then commit them if everything looks good."
    end

    def term_uris_for_adapter(adapter)
      q = "MATCH (t:Term)\n"\
        "WHERE t.uri =~ '#{adapter.uri_regexp}'\n"\
        "RETURN t.uri\n"\
        "LIMIT #{TERM_LIMIT}"
      result = TraitBank.query(q)
      result["data"].collect { |r| r[0] }
    end

    def term_uris_for_geonames
      puts term_uris_for_adapter(TermNames::GeonamesAdapter)
    end

    def backup_file(file_path, bak_path)
      if File.exist?(file_path)
        puts "Copying existing file #{file_path} to #{bak_path}"
        FileUtils.cp(file_path, bak_path)
      end
    end
  end
end

