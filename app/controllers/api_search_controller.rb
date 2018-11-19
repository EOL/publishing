class ApiSearchController < LegacyApiController
  def index
    respond_to do |format|
      results = get_results
      format.json { render json: results }
      format.xml { render xml: results.to_xml }
    end
  end

  private

  def get_results
    params[:page] ||= 1
    @per_page = 50
    if params[:filter_by_string]
      results = Page.autocomplete(params[:filter_by_string])
      @clade = results.results.first['id'] if results && results.results&.any?
    elsif id = params[:filter_by_taxon_concept_id]
      @clade = params[:filter_by_taxon_concept_id]
    elsif params[:filter_by_hierarchy_entry_id]
      return { 'response' => { 'message' => 'filter_by_hierarchy_entry_id is no longer supported. Please obtain the corresponding page id and use filter_by_taxon_concept_id.' } }
    end

    fields = %w[preferred_vernacular_strings^20 vernacular_strings^20 preferred_scientific_names^10 scientific_name^10
                synonyms^10 resource_pks]
    # Basically stolen from SearchController, but highlight wasn't working AT ALL... so I skipped it.
    pages = Page.search(params[:q],
      page: params[:page], per_page: 50,
      boost_by: [:page_richness, :specificity, :depth], match: :phrase, fields: fields,
      where: @clade ? { ancestry_ids: @clade.id } : nil,
      includes: [:scientific_names, :nodes, :preferred_vernaculars, :native_node])

    results = []
    pages.results.each do |result|
      result_hash = {}
      result_hash[:id] = result.id
      node = result.safe_native_node
      next unless node
      result_hash[:title] = node.canonical_form
      result_hash[:link] = url_for(controller: 'pages', action: 'show', id: result.id)

      result_hash[:content] = []
      result_hash[:content] << node.canonical_form if node.canonical_form =~ /#{params[:q]}/i
      result.scientific_names.each do |name|
        result_hash[:content] << name.verbatim if name.verbatim =~ /#{params[:q]}/i
      end
      result.synonyms.each do |name|
        result_hash[:content] << name if name =~ /#{params[:q]}/i
      end
      result.vernacular_strings.each do |name|
        result_hash[:content] << name if name =~ /#{params[:q]}/i
      end
      result_hash[:content] = result_hash[:content].uniq.join('; ')
      results << result_hash
    end

    return_hash = {}
    return_hash[:totalResults] = pages.total_count
    return_hash[:startIndex]   = ((params[:page].to_i) * @per_page) - @per_page + 1
    return_hash[:itemsPerPage] = @per_page
    return_hash[:results]      = results
    return_hash
  end
end
