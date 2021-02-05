module TraitBank
  module Resource
    class << self
      def find(id)
        res = TraitBank.query("MATCH (resource:Resource { resource_id: #{id} }) RETURN resource LIMIT 1")
        res["data"] ? res["data"].first : false
      end

      def create(id_param)
        id = id_param.to_i
        return "#{id_param} is not a valid positive integer id!" if
          id_param.is_a?(String) && !id.positive? && id.to_s != id_param
        if (resource = find(id))
          return resource
        end
        resource = TraitBank::Admin.connection.create_node(resource_id: id)
        TraitBank::Admin.connection.set_label(resource, 'Resource')
        resource
      end
    end
  end
end
