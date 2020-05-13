# e.g.: VernacularNamesDumper.create_names_dump ...not much else to say about this one.
class VernacularNamesDumper
  class << self
    def create_names_dump
      dumper = VernacularNamesDumper.new
      dumper.create_names_dump
    end
  end

  def initialize
    @output_path = Rails.public_path.join('data', 'vernacular_names.csv')
  end

  def create_names_dump
    CSV.open(@output_path, "wb") do |csv|
      csv << %w[
        page_id
        canonical_form
        vernacular_string
        language_code
        resource_name
        is_preferred_by_resource
        is_preferred_by_eol
      ]
      Vernacular.includes(:resource, :language, page: { native_node: :scientific_names } ).find_each do |vernacular|
        csv << [
          vernacular.page_id,
          vernacular.page&.canonical || '',
          vernacular.string,
          vernacular.language&.code || '',
          vernacular.resource&.name || '',
          vernacular.is_preferred_by_resource ? 'preferred' : '',
          vernacular.is_preferred ? 'preferred' : ''
        ]
      end
    end
  end
end
