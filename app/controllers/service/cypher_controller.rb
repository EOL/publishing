# Cypher query via web services API

require 'csv'

class Service::CypherController < ServicesController
  before_action :require_power_user, only: :form

  def form
    # Cf. the view
  end
  
  def query
    format = params.delete(:format) || "cypher"

    cypher = params.delete(:query)
    return render_bad_request(title: "Missing a 'query' parameter.") unless
      cypher != nil

    # Deletion is forbidden in order to help prevent catastrophic
    # mistakes.
    # The purpose of the 'limit' is to help prevent unintended DoS 
    # attacks.
    # The regexes below are ad hoc filters to try to prevent problems,
    # at least when accidental.  We don't expect these permission
    # checks to provide security against a concerted attack.

    return render_bad_request(title: "Please provide a LIMIT clause.") unless
      cypher =~ /\b(limit)\b/i
      
    # Authenticate the user and authorize the requested operation, 
    # using the API token and the information in the user table.
    # Non-admin users are not supposed to add to the database.
    
    if cypher =~ /\b(create|set|merge|load|delete|remove|call)\b/i
      # Allow admin to add to graph and perform dangerous operations
      user = authorize_admin_from_token!
      return nil unless user
    elsif
      # Power users can only read
      user = authorize_user_from_token!
      return nil unless user
    end

    # Do the query or command
    render_results(TraitBank.query(cypher), format)
  end

  def render_results(results, format = "cypher")
    case format
    when "cypher" then
      render json: results
    when "csv" then
      self.content_type = 'text/csv'
      # Streaming output
      self.response_body =
        Enumerator.new do |y|
          y << CSV.generate_line(results["columns"])
          results["data"].each do |row|
            y << CSV.generate_line(row)
          end
        end    # end Enumerator
    else
      return render_bad_request(title: "Unrecognized 'format' parameter value.", format: format)
    end        # end case
  end          # end def

  def remove_relationships
    format = params[:format] || "cypher"

    return render_bad_request(title: "Relation parameter is missing") unless
      params.include?(:relation)
    relation = params[:relation]
    # Fixed set of allowed relationships
    # (Currently only one...)
    return render_bad_request(title: "Unrecognized relation #{relation}") unless
      ["inferred_trait"].include?(relation)

    return render_bad_request(title: "Resource parameter is missing") unless
      params.include?(:resource)
    resource_id = Integer(params[:resource])

    return nil unless
      authorize_admin_from_token!
    render_results(TraitBank.query(
                    "MATCH ()-[rel:#{relation}]-
                           (t:Trait)-[:supplier]->
                           (:Resource {resource_id: #{resource_id}})
                     DELETE rel
                     RETURN t.resource_pk"))
  end

end            # end class



