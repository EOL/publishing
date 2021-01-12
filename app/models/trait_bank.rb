# Abstraction between our traits and the implementation of their storage. ATM, we use neo4j. THE SCHEMA FOR TRAITS CAN
# BE FOUND IN db/neo4j_schema.md ...please read that file before attempting to understand this one. :D
module TraitBank
  include TraitBank::Constants

  class << self
    def resources(traits)
      resources = Resource.where(id: traits.map { |t| t[:resource_id] }.compact.uniq)
      # A little magic to index an array as a hash:
      Hash[ *resources.map { |r| [ r.id, r ] }.flatten ]
    end


    def find_resource(id)
      res = TraitBank::Connector.query("MATCH (resource:Resource { resource_id: #{id} }) RETURN resource LIMIT 1")
      res["data"] ? res["data"].first : false
    end

    def create_resource(id_param)
      id = id_param.to_i
      return "#{id_param} is not a valid positive integer id!" if
        id_param.is_a?(String) && !id.positive? && id.to_s != id_param
      if (resource = find_resource(id))
        return resource
      end
      resource = connection.create_node(resource_id: id)
      connection.set_label(resource, 'Resource')
      resource
    end

    def relate(how, from, to)
      begin
        connection.create_relationship(how, from, to)
      rescue
        # Try again...
        begin
          sleep(0.1)
          connection.create_relationship(how, from, to)
        rescue Neography::BadInputException => e
          TraitBank::Logger.log_error("** ERROR adding a #{how} relationship:\n#{e.message}")
          TraitBank::Logger.log_error("** from: #{from}")
          TraitBank::Logger.log_error("** to: #{to}")
        rescue Neography::NeographyError => e
          TraitBank::Logger.log_error("** ERROR adding a #{how} relationship:\n#{e.message}")
          TraitBank::Logger.log_error("** from: #{from}")
          TraitBank::Logger.log_error("** to: #{to}")
        rescue Excon::Error::Socket => e
          puts "** TIMEOUT adding relationship"
          TraitBank::Logger.log_error("** ERROR adding a #{how} relationship:\n#{e.message}")
          TraitBank::Logger.log_error("** from: #{from}")
          TraitBank::Logger.log_error("** to: #{to}")
        end
      end
    end

    def get_name(trait, which = :predicate)
      if trait && trait.has_key?(which)
        if trait[which].has_key?(:name)
          trait[which][:name]
        elsif trait[which].has_key?(:uri)
          humanize_uri(trait[which][:uri]).downcase
        else
          nil
        end
      else
        nil
      end
    end

    # each argument is expected to be an Array of strings
    def array_to_qs(*args)
      result = []
      args.each do |uris|
        result.concat(uris.collect { |uri| "'#{uri}'" })
      end
      "[#{result.join(", ")}]"
    end

    # default direction is outgoing.
    def count_rels_by_direction(node, direction = nil)
      relationship = direction == :incoming ? '<-[relationship]-' : '-[relationship]->'
      TraitBank::Connector.query("MATCH (#{node})#{relationship}() RETURN COUNT(relationship)")['data'].first.first
    end
  end
end
