class ApplicationController < ActionController::Base
  before_filter :set_locale

  helper_method :is_admin?

  # For demo, we're using Basic Auth:
  if Rails.application.secrets.user_id
    before_filter :authenticate
  end

  protected
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == Rails.application.secrets.user_id &&
        password == Rails.application.secrets.password
      end
    end

    def is_admin?
      current_user && current_user.is_admin?
    end

    def default_url_options(options={})
     { secure: true }
    end

  public

  # Authorization:
  include Pundit
  # TODO: we may want to use :null_session when for the API, when we set that up.
  protect_from_forgery with: :exception
  def logged_in?
    session[:user_id] && current_user.active?
  end

  def clear_cached_summaries
    (0..9).each do |bucket|
      array = Rails.cache.read("constructed_summaries/#{bucket}")
      if array
        array.each do |page_id|
          Rails.cache.delete("constructed_summary/#{page_id}")
        end
      end
    end
  end

private

  def set_locale
    I18n.locale = params[:lang] || I18n.default_locale
  end
end
