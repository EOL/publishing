# Cypher query via web services API

class CypherController < ServicesController

  def index
    authorize_user_from_token!
    if params[:query]
      # TBD: filter out create, delete, etc
      cypher = params[:query]
    else
      # default for testing.  remove this before release.
      cypher = "MATCH (n:Page) RETURN n.page_id LIMIT 10;"
    end

    # Web users are not supposed to modify the database.  The following
    # is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    if cypher =~ /\w(delete|create|set|remove|merge|call|drop|load)\w/i
      render status: 403    #403 = forbidden (401 means unauthenticated)
    else
      render json: TraitBank.query(cypher)
    end
  end
end
