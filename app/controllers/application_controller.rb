class ApplicationController < ActionController::Base
  before_filter :set_locale

  # Authorization:
  include Pundit
  # TODO: we may want to use :null_session when for the API, when we set that up.
  protect_from_forgery with: :exception
  def logged_in?
    session[:user_id] && current_user.active?
  end

private

  def set_locale
    I18n.locale = params[:lang] || I18n.default_locale
  end
end
