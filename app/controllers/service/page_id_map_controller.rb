
require 'csv'

class Service::PageIdMapController < ServicesController
  #before_action :require_power_user, only: :form
  #skip_before_action :verify_authenticity_token, only: :command

  def get
    self.content_type = 'text/csv'
    resource_id = params["resource"].to_i
    $stderr.puts "Resource id: #{resource_id}"
    r = Resource.find(resource_id)
    $stderr.puts "Resource: #{r}"
    if not r
      render json: payload.merge(:title => "Resource not found",
                                 :status => "404 Page Not Found"),
             status: 404
      nil
    else
      self.response_body =
        Enumerator.new do |y|
          y << CSV.generate_line(["id", "page_id"])
          Node.where(resource_id: resource_id) do |node|
            y << CSV.generate_line([node.id, node.page_id])
          end
        end    # end Enumerator
    end
  end

end

