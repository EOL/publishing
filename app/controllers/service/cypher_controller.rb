# Cypher query via web services API

class Service::CypherController < ServicesController
  before_action :require_power_user, only: :form

  def form
  end

  def query
    return unless authorize_user_from_token!
    cypher = params[:query]

    # Web users are not supposed to modify the database.  The following
    # is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    if cypher =~ /\b(delete|create|set|remove|merge|call|drop|load)\b/i
      render_unauthorized errors: {forbidden: ["You are not authorized to use this command."]}
    elsif cypher =~ /\b(limit)\b/i
      render json: TraitBank.query(cypher)
    else
      render_unauthorized errors: {forbidden: ["You must specify a LIMIT for this operation."]}
    end
  end
end
