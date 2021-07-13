module Reconciliation
  class DataExtensionQuery
    def initialize(raw_query)
      ids = raw_query['ids']
      raise TypeError, "'ids' property missing" unless ids
      raw_props = raw_query['properties']
      raise TypeError, "'properties' property missing" unless raw_props

      properties = build_properties(raw_props)
    end

    private
    def build_properties(raw_props)
      raw_props.each do |p|
        id = p['id']

        if Reconciliation::PropertyType.id_valid?(id)
          # TODO
        else
          raise TypeError, "bad property id: #{id}"
        end
      end
    end
  end
end

