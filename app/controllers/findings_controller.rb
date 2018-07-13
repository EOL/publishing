# The rule for rails is: controller should be minimal; the logic
# should be in the model.  Further down the road there will be an api
# model (class, not db table), but for now this one method is simple
# enough, and control-related enough, that it can all go in the
# controller.  -JAR commenting on his first rails method

class FindingsController < ApplicationController
  before_action :require_power_user

  def cypher
    if params[:query]
      # TBD: filter out create, delete, etc
      cypher = params[:query]
    else
      # default for testing.  remove this before release.
      cypher = "MATCH (n:Page) RETURN n.page_id LIMIT 10;"
    end

    # Power user are not supposed to modify the database.  The following
    # is an ad hoc filter to try to prevent this, at least when it is 
    # accidental; one shouldn't expect it to be secure against a concerted attack.
    if cypher =~ /\w(delete|create|set|remove|merge|call|drop|load)\w/i
      render status: 403    #403 = forbidden (401 means unauthenticated)
    else
      render json: TraitBank.query(cypher)
    end
  end
end
