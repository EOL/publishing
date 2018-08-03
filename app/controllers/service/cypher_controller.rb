# Cypher query via web services API

class Service::CypherController < ServicesController

  def index
    return unless authorize_user_from_token!
    cypher = params[:query]

    # Web users are not supposed to modify the database.  The following
    # is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    if cypher =~ /\b(delete|create|set|remove|merge|call|drop|load)\b/i
      render_unauthorized errors: {forbidden: ["You are not authorized to use this command."]}
    else
      render json: TraitBank.query(cypher)
    end
  end
end
