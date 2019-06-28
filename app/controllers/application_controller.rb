require "robots_util"

class ApplicationController < ActionController::Base
  before_filter :set_locale
  before_filter :set_robots_header

  helper_method :is_admin?
  helper_method :is_power_user?
  helper_method :main_container?

  ROBOTS_DISALLOW_PATTERNS = Rails.application.config.x.robots_disallow_patterns
  ROBOTS_DISALLOW_REGEXPS = RobotsUtil.url_patterns_to_regexp(ROBOTS_DISALLOW_PATTERNS)
  DEFAULT_BREADCRUMB_TYPE = "vernacular"


  # For demo, we're using Basic Auth:
  if Rails.application.secrets.user_id
    before_filter :authenticate
  end

  def route_not_found
    respond_to do |format|
      format.html { render 'error_pages/404', status: :not_found }
      format.all { redirect_to :controller => 'application', :action => 'route_not_found' }
    end
  end

  def default_url_options(options = {})
    locale = (I18n.locale == I18n.default_locale) ? nil : I18n.locale
    { locale: locale }.merge options
  end
  
  # robots.txt
  def robots
    respond_to do |format|
      format.text do
        if Rails.application.config.x.block_crawlers
          @disallow_patterns = ["/"]
        else
          @disallow_patterns = ROBOTS_DISALLOW_PATTERNS
        end
      end
    end
  end

  def set_breadcrumb_type
    type = params[:type]

    if type != "vernacular" && type != "canonical"
      raise "invalid type param: #{type}"
    end

    session[:breadcrumb_type] = type
    redirect_to (request.referrer || home_path)
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

    def is_power_user?
      current_user && current_user.is_power_user?
    end

    # https://stackoverflow.com/questions/3297048/403-forbidden-vs-401-unauthorized-http-responses
    def require_admin
      raise "Unauthorized" unless current_user
      raise "Forbidden" unless current_user.is_admin?
    end

    def require_power_user
      raise "Unauthorized" unless current_user
      raise "Forbidden" unless current_user.is_power_user?
    end

    def no_main_container
      @nocontainer = true
    end

    def main_container?
      !@nocontainer
    end

    def breadcrumb_type
      session[:breadcrumb_type] || DEFAULT_BREADCRUMB_TYPE
    end
    helper_method :breadcrumb_type

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
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def set_robots_header
    noindex = Rails.application.config.x.block_crawlers

    if !noindex
      noindex = ROBOTS_DISALLOW_REGEXPS.any? { |re| request.path =~ re }
    end

    if noindex
      response.headers['X-Robots-Tag'] = "noindex"
    end
  end

end
