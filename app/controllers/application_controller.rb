class ApplicationController < ActionController::Base
  # Authorization:
  include Pundit
  # TODO: we may want to use :null_session when for the API, when we set that up.
  protect_from_forgery with: :exception

  helper_method :policy

end
