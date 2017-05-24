class ApiController < ApplicationController
  def pages
    @api_method = "API::Pages".camelize.constantize
  end
  
  def collections
    @api_method = "API::Collections".camelize.constantize
  end
end