class TraitBank::RecordDownloadWriter
  # These are handled as ordered columns
  HEADER_GLOSSARY = {
    "http://rs.tdwg.org/dwc/terms/measurementType" => {
      :label => "Measurement Type",
      :definition => "The nature of the measurement, fact, characteristic, or assertion. Recommended best practice is to use a controlled vocabulary."
    },
    "http://rs.tdwg.org/dwc/terms/measurementValue" => {
      :label => "Measurement Value",
      :definition => "The value of the measurement, fact, characteristic, or assertion."
    },
    "http://rs.tdwg.org/dwc/terms/measurementUnit" => {
      :label => "Measurement Unit",
      :definition => "The units associated with the measurementValue. Recommended best practice is to use the International System of Units (SI)."
    },
    "http://rs.tdwg.org/dwc/terms/measurementRemarks" => {
      :label => "Measurement Remarks",
      :definition => "Comments or notes accompanying the MeasurementOrFact."
    },
    "http://rs.tdwg.org/dwc/terms/measurementMethod" => {
      :label => "Measurement Method",
      :definition => "A description of or reference to (publication, URI) the method or protocol used to determine the measurement, fact, characteristic, or assertion."
    },
    "http://eol.org/schema/terms/statisticalMethod" => {
      :label => "Statistical Method",
      :definition => "The method which was used to process an aggregate of values."
    },
    "http://rs.tdwg.org/dwc/terms/sex" => {
      :label => "Sex",
      :definition => "The sex of the biological individual(s) represented in the Occurrence. Recommended best practice is to use a controlled vocabulary."
    },
    "http://rs.tdwg.org/dwc/terms/lifeStage" => {
      :label => "Life Stage",
      :definition => "The age class or life stage of the biological individual(s) at the time the Occurrence was recorded. Recommended best practice is to use a controlled vocabulary."
    },
    "http://eol.org/schema/terms/SampleSize" => {
      :label => "Sample Size",
      :definition => "The size of the sample upon which a measurement is based."
    },
    "http://purl.org/dc/terms/source" => {
      :label => "Source",
      :definition => "The described resource may be derived from the related resource in whole or in part. Recommended best practice is to identify the related resource by means of a string conforming to a formal identification system."
    },
    "http://purl.org/dc/terms/bibliographicCitation" => {
      :label => "Bibliographic Citation",
      :definition => "Recommended practice is to include sufficient bibliographic detail to identify the resource as unambiguously as possible."
    },
    "http://purl.org/dc/terms/contributor" => {
      :label => "Contributor",
      :definition => "Examples of a Contributor include a person, an organization, or a service."
    },
    "http://eol.org/schema/reference/referenceID" => {
      :label => "Reference ID",
      :definition => "Reference ID definition"
    }
  }

  IGNORE_META_URIS = HEADER_GLOSSARY.keys

  def start_cols # rubocop:disable Metrics/CyclomaticComplexity
    { "EOL Page ID" => -> (trait, page, association) { page&.id },# NOTE: might be nice to make this clickable?
      "Ancestry" => -> (trait, page, association) { TraitBank::DownloadUtils.ancestry(page) },
      "Scientific Name" => -> (trait, page, association) { page&.scientific_name },
      "Measurement Type" => -> (trait, page, association) { handle_term(trait[:predicate]) },
      "Measurement Value" => -> (trait, page, association) do 
        trait[:measurement] || handle_term(trait[:object_term]) || handle_association(trait, association) # Raw value, not sure if this works for associations
      end,
      "Measurement Unit" => -> (trait, page, association) { handle_term(trait[:units]) },
      "Measurement Accuracy" => -> (trait, page, association) { meta_value(trait, "http://rs.tdwg.org/dwc/terms/measurementAccuracy") },
      "Measurement Remarks" => -> (trait, page, association) { trait[:remarks] },
      "Measurement Method" => -> (trait, page, association) { trait[:method] },
      "Statistical Method" => -> (trait, page, association) { handle_term(trait[:statistical_method_term]) },
      "Target EOL ID" => -> (trait, page, association) { association&.id },
      "Target EOL Name" => -> (trait, page, association) { association&.scientific_name },
      "Target Source Name" => -> (trait, page, association) { trait[:target_scientific_name] },
      "Sex" => -> (trait, page, association) { handle_term(trait[:sex_term])},
      "Life Stage" => -> (trait, page, association) { handle_term(trait[:lifestage_term]) },
      "Sample size" => -> (trait, page, association) { trait[:sample_size] },
    }
  end

  def end_cols
    {
      "Source" => -> (trait, page) { trait[:source] },
      "Bibliographic Citation" => -> (trait, page) { handle_citation(trait[:citation]) },
      "Contributor" => -> (trait, page) { meta_value(trait, "http://purl.org/dc/terms/contributor") },
      "Reference ID" => -> (trait, page) { handle_reference(meta_value(trait, "http://eol.org/schema/reference/referenceID")) },
      "Resource URL" => -> (trait, page) do 
        (
          trait[:resource] ? 
          TraitBank::DownloadUtils.resource_path(:resource, trait[:resource][:resource_id]) :
          nil
        )
      end
    #TODO: deal with references
    }
  end
  
  def initialize(hashes, base_filename, search_url)
    @hashes = hashes
    @directory_name = base_filename
    @zip_filename = "#{base_filename}.zip"
    @trait_filename = "data_#{base_filename}.tsv"
    @glossary_filename = "glossary_#{base_filename}.tsv"
    @glossary = HEADER_GLOSSARY.clone
    @citations = Set.new
    @ref_id = 0
    @references = {}
    @url = search_url
  end

  def write
    get_predicates
    to_arrays
    write_csv
    write_glossary
    write_zip
    @zip_filename
  end

  def handle_term(term)
    if term
      if term[:uri]
        @glossary[term[:uri]] = {
          :label => term[:name],
          :definition => term[:definition]
        }
      end
      term[:name]
    else
      nil
    end
  end

  def handle_association(term, association)
  
  end 

  def handle_citation(cit)
    if !cit.blank?
      @citations.add(cit)
    end

    cit
  end

  def handle_reference(reference)
    if !reference.blank?
      if !@references.key?(reference)
        @references[reference] = @ref_id
        @ref_id += 1
      end
      
      @references[reference]
    else
      nil
    end
  end

  def track_value(i, val, cols_with_vals)
    cols_with_vals.add(i) if val
    val
  end

  def to_arrays
    @data = []
    @data << start_cols.keys + @predicates.keys + end_cols.keys
    cols_with_vals = Set.new

    @hashes.in_groups_of(10_000, false) do |hashes|
      pages = Page.where(id: page_ids(hashes))
        .includes(
          :preferred_vernaculars, 
          { 
            native_node: [
              { node_ancestors: [:ancestor] }, 
              :scientific_names 
            ]
          }
        )
        .map { |p| [p.id, p] }.to_h
      associations = Page.with_scientific_name.where(id: association_ids(hashes))
        .map { |p| [p.id, p] }.to_h

      hashes.each do |trait|
        page = pages[trait[:page_id]]
        association = associations[trait[:object_page_id]]
        row = []
        i = 0

        start_cols.each do |_, lamb|
          row << track_value(i, lamb[trait, page, association], cols_with_vals)
          i += 1
        end

        @predicates.values.each do |predicate|
          @glossary[predicate[:uri]] = {
            :label => predicate[:name],
            :definition => predicate[:definition]
          }
          row << track_value(i, meta_value(trait, predicate[:uri]), cols_with_vals)
          i += 1
        end

        end_cols.each do |_, lamb|
          row << track_value(i, lamb[trait, page], cols_with_vals)
          i += 1
        end

        @data << row
      end
    end

    remove_blank_cols(@data, cols_with_vals)
    @data
  end

  def remove_blank_cols(data, cols_with_vals)
    data.each do |row| 
      row.delete_if.with_index { |_, i| !cols_with_vals.include? i }
    end

    data
  end

  def generate_csv
    CSV.generate(col_sep: "\t") do |csv|
      @data.each { |row| csv << row }
    end
  end

  def write_csv
    CSV.open(TraitBank::DataDownload.path.join(@trait_filename), "wb", :col_sep => "\t") do |csv|
      @data.each { |row| csv << row }
    end
  end

  def write_glossary
    CSV.open(TraitBank::DataDownload.path.join(@glossary_filename), "wb", :col_sep => "\t") do |csv|
      csv << ["Glossary"]
      csv << ["Label", "URI", "Definition"]
      @glossary.each do |uri, item|
        csv << [item[:label], uri, item[:definition]]
      end

      csv << []
      csv << ["Sources and citations"]
      @citations.each do |cit|
        csv << [cit]
      end

      csv << []
      csv << ["References"]
      csv << ["Id", "Reference"]
      @references.map { |ref, id| [id, ref] }.sort { |a, b| a[0] <=> b[0] }.each do |pair|
        csv << [pair]
      end

      csv << []
      csv << ["Search URL"]
      csv << [@url]
    end
  end

  def meta_value(trait, uri) 
    metas = trait[:metadata].select { |m| m[:predicate][:uri] == uri }
    metas.any? ? join_metas(metas) : nil
  end

  def join_metas(metas)
    metas.map do |meta|
      meta[:object_term] ? handle_term(meta[:object_term]) : meta[:literal]
    end.uniq.join(" | ")
  end

  def page_ids(hashes)
    TraitBank::DownloadUtils.page_ids(hashes)
  end

  def association_ids(hashes)
    hashes.map { |hash| hash[:object_page_id] }.uniq.compact
  end

  def get_predicates
    @predicates = {}
    @hashes.each do |hash|
      next unless hash[:metadata]
      hash[:metadata].each do |meta|
        next if IGNORE_META_URIS.include?(meta[:predicate][:uri])
        name = meta[:predicate][:name].titleize rescue ""
        name ||= meta[:predicate][:uri]
        @predicates[name] ||= meta[:predicate]
      end
    end
  end

  def write_zip
    Zip::File.open(TraitBank::DataDownload.path.join(@zip_filename), Zip::File::CREATE) do |zipfile|
      zipfile.mkdir(@directory_name)
      zipfile.add("#{@directory_name}/#{@trait_filename}", TraitBank::DataDownload.path.join(@trait_filename))
      zipfile.add("#{@directory_name}/#{@glossary_filename}", TraitBank::DataDownload.path.join(@glossary_filename))
    end
  end
end
