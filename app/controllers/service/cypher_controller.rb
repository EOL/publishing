# Cypher query via web services API

require 'csv'

class Service::CypherController < ServicesController
  before_action :require_power_user, only: :form

  def form
  end

  def query
    return unless authorize_user_from_token!
    cypher = params[:query]
    format = params[:format]
    format = "cypher" unless format != nil

    if cypher == nil
      render_bad_request(title: "Missing a 'query' parameter.")

    # Web users are not supposed to modify the database.  The following
    # is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    elsif cypher =~ /\b(delete|create|set|remove|merge|call|drop|load)\b/i
      render_unauthorized(title: "You are not authorized to use this Cypher command.")
    elsif cypher =~ /\b(limit)\b/i
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
        render_bad_request(title: "Unrecognized 'format' parameter value.", format: format)
      end        # end case
    else
      render_unauthorized(title: "You must specify a LIMIT for this operation.")
    end
  end
end
