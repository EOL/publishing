class TraitBank
  class TermSearchCounts
    attr_reader :records, :pages

    def initialize(res)
      record_count_index = res["columns"].index("record_count")
      page_count_index = res["columns"].index("page_count")

      if record_count_index.nil? || page_count_index.nil?
        raise TypeError.new("column missing from result")
      end

      @records = res["data"].first[record_count_index]
      @pages = res["data"].first[page_count_index]
    end

    def primary_for_query(query)
      if query.record?
        records
      else
        pages
      end
    end
  end
end

