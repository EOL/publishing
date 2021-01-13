class TraitSearch
  def initialize(term_query)
    raise TypeError, "term_query can't be nil" if term_query.nil?

    @query = term_query
    @per_page = DEFAULT_PER_PAGE
    @page = DEFAULT_PAGE
  end  

  def query
    @query

    self
  end

  def per_page(value)
    raise TypeError, 'must be > 0' unless value > 0

    @per_page = value

    self
  end

  def page(value)
    raise TypeError, 'must be > 0' unless value > 0    

    @page = value

    self
  end

  def count
    @count ||= TraitBank::Search.term_search(@query, count: true)
      .primary_for_query(@query)
  end

  def results
    return @results if @results

    response = TraitBank::Search.term_search(@query, page: @page, per: @per_page)
    @results = response

    # TODO: new response types
  end

  private
  DEFAULT_PER_PAGE = 50
  DEFAULT_PAGE = 1
end
