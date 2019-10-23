# Cypher query via web services API

require 'csv'

class Service::CypherController < ServicesController
  before_action :require_power_user, only: :form

  def form
    # Cf. the view
  end
  
  # Entry via POST for uncacheable / unsafe operations
  def command
    cypher_command(params, true)
  end

  # Entry via GET for cacheable / safe operations
  def query
    cypher_command(params, false)
  end

  def cypher_command(params, allow_effectful)
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
    
    if cypher =~ /\b(create|set|merge|delete|remove|call)\b/i
      return render_bad_request(title: "Unsafe Cypher operation.") unless
        allow_effectful
      # Allow admin to perform dangerous operations via POST
      user = authorize_admin_from_token!
      return nil unless user
    else
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



=begin

I didn't know where to put tests, and these take a bit of setup, so
rather than lose what might have been useful work (they did help me
find bugs), I'm just dumping the tests here in this comment. -JAR

Create three users with different authorization levels:

bin/rails r 'user = User.create!({email: "qwy103@mumble.net", username: "eol3", password: "x", role: :user}); user.activate'
bin/rails r 'user = User.create!({email: "qwy104@mumble.net", username: "eol4", password: "x", role: :power_user}); user.activate'
bin/rails r 'user = User.create!({email: "qwy105@mumble.net", username: "eol5", password: "x", role: :admin}); user.activate'

Get the tokens for the three users:

bin/rails r 'puts(ServicesController.jwt_token(User.where(email: "qwy103@mumble.net").last))'
bin/rails r 'puts(ServicesController.jwt_token(User.where(email: "qwy104@mumble.net").last))'
bin/rails r 'puts(ServicesController.jwt_token(User.where(email: "qwy105@mumble.net").last))'

Test all nine combinations of auth level + request class:

for auth in varela-user varela varela-admin; do
  for query in "MATCH (p:Page) RETURN p.page_id" \
               "MATCH (p:Page) RETURN p.page_id LIMIT 2" \
               "MATCH (p:Page {page_id:0}) DELETE (p) RETURN p.page_id LIMIT 2"; do
    echo "### Test $auth"
    python3 doc/cypher.py --format csv \
            --server http://127.0.0.1:3000/ --tokenfile ~/Sync/eol/$auth.token \
            --query "$query"
  done
done

=end
