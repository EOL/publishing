module Reconciliation
  class DataExtensionQuery
    attr_reader :page_hash, :properties

    def initialize(raw_query)
      ids = raw_query['ids']
      raise ArgumentError, "'ids' property missing" unless ids
      raw_props = raw_query['properties']
      raise ArgumentError, "'properties' property missing" unless raw_props

      @properties = build_properties(raw_props)
      @page_hash = resolve_ids(ids)
    end

    private
    def build_properties(raw_props)
      raise TypeError, "'properties' must be an Array" unless raw_props.is_a?(Array)

      raw_props.map do |p|
        id = p['id']

        if Reconciliation::PropertyType.id_valid?(id)
          Reconciliation::PropertyType.for_id(id)
        else
          raise ArgumentError, "bad property id: #{id}"
        end
      end
    end

    def resolve_ids(raw_ids)
      raise TypeError, "'ids' must be an Array" unless raw_ids.is_a?(Array)

      Reconciliation::TaxonEntityResolver.resolve_ids(raw_ids)
    end
  end
end

