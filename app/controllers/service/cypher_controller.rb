# Cypher query via web services API

require 'csv'

class Service::CypherController < ServicesController
  before_action :require_power_user, only: :form

  def form
    # Cf. the view
  end

  def query
    cypher = params[:query]
    format = params[:format]
    format = "cypher" unless format != nil

    return render_bad_request(title: "Missing a 'query' parameter.") \
      unless cypher != nil

    # Non-admin users are not supposed to modify the database.  The following
    # is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    if cypher =~ /\b(delete|create|set|remove|merge|call|drop|load)\b/i ||
       cypher =~ /\b(limit)\b/i
      return unless authorize_admin_from_token!
    else
      return unless authorize_user_from_token!
    end

    # Do the query or command
    case format
    when "cypher" then
      render json: TraitBank.query(cypher)
    when "csv" then
      self.content_type = 'text/csv'
      results = TraitBank.query(cypher)
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
end            # end class



