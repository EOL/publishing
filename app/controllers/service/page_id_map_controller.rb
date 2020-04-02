# This is a web service for obtaining the mapping between
# resource-specific node ids (resource_pk field, usually from taxonID
# column in the opendata resource) and page ids, for a specific
# resource. (This mapping is created in the first place by the name
# matcher.) This gives a toehold for comparing graphdb contents with
# opendata resources, and for extending the graphdb with information in
# opendata resources. The immediate need for this service was to get
# vernaculars into the graphdb, but I expect it to have other uses,
# e.g. I may rewrite the ranks 'script' to use this service instead of
# the provider_ids.csv file.

# Parameters are resource (id), limit, skip. The default limit is 100000.

# Testing has been minimal, just manual tests using wget e.g.
# wget -O - "http://localhost:3000/service/page_id_map?resource=40&limit=5"

# Does the http client have to be authenticated (using a token)? I don't
# see this as important, but it's easy enough to un-comment the
# lines that handle this.

require 'csv'

class Service::PageIdMapController < ServicesController
  #before_action :require_power_user, only: :form
  #skip_before_action :verify_authenticity_token, only: :command

  def get
    self.content_type = 'text/csv'
    resource_id = params["resource"].to_i
    r = Resource.find(resource_id)
    if not r
      render json: payload.merge(:title => "Resource not found",
                                 :status => "404 Page Not Found"),
             status: 404
      nil
    else
      self.response_body =
        Enumerator.new do |y|
          y << CSV.generate_line(["resource_pk", "page_id"])
          limit = (params.key?("limit") ? params["limit"].to_i : 100000)
          skip  = (params.key?("skip")  ? params["skip"].to_i  : 0)
          Node.where(resource_id: resource_id).select(:resource_pk, :page_id).offset(skip).limit(limit).each do |node|
            y << CSV.generate_line([node.resource_pk, node.page_id])
          end
        end    # end Enumerator
    end
  end

end

