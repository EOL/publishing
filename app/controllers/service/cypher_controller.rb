# Cypher query via web services API

require 'csv'

class Service::CypherController < ServicesController
  before_action :require_power_user, only: :form

  def form
    # Cf. the view
  end

  def query
    cypher = params[:query]
    return render_bad_request(title: "Missing a 'query' parameter.") \
      unless cypher != nil

    format = params[:format]
    format = "cypher" unless format != nil

    # Authenticate the user and authorize the requested operation, using
    # the API token and the user's information in the table.
    # Non-admin users are not supposed to modify the database.  The following
    # regex is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    # The purpose of the 'limit' is to help prevent unintended DoS 
    # attacks.
    if cypher =~ /\b(delete|create|set|remove|merge|call|drop|load)\b/i
      user = authorize_admin_from_token!
    elsif cypher =~ /\b(limit)\b/i
      user = authorize_user_from_token!    # power user that is
    elsif
      user = authorize_admin_from_token!
    end
    return nil unless user

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



