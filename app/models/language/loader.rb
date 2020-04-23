class Language
  class Loader
    class << self
      def load_file(file_path)
        reader = Language::Loader.new
        CSV.foreach(file_path) do |line|
          reader.read(line)
        end
        reader.finish
      end

      def parse(string)
        reader = Language::Loader.new
        CSV.parse(string) do |line|
          reader.read(line)
        end
        reader.finish
      end
    end

    def initialize()
      require 'csv'
      @known_codes = {}
      Language.where('code IS NOT NULL').pluck(:code).each do |code|
        @known_codes[code] = true
      end
      @new_languages = []
    end

    def finish
      unless @new_languages.blank?
        puts "You will have to add the following lines manually to the en.yml file under the 'languages:' heading:"
        puts @new_languages.join("\n")
      end
    end

    def read(line)
      (code, group, name) = line
      return if name.blank?
      # NOTE: it's true, the name of the langauge is NOT stored in the database. It's in the en.yml file.
      if @known_codes.key?(code)
        lang = Language.find_by_code(code)
        lang.group = line[1]
        lang.save!
      else
        Language.create(code: code, group: group, can_browse_site: false)
        @new_languages << %Q{    #{group}: "#{name}"}
      end
    end
  end
end
