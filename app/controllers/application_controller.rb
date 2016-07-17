class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def fetch_user
    debugger
    found = User.find_by_email(params[:email]) ? true : false
    respond_to do |format|
      format.html {}
      format.json { render json: found }
    end
  end
end