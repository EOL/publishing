require "robots_util"
require "breadcrumb_type"

class ApplicationController < ActionController::Base
  before_action :set_locale
  before_action :set_robots_header
  before_action :set_last_regular_path

  helper_method :is_admin?
  helper_method :is_power_user?
  helper_method :main_container?

  ROBOTS_DISALLOW_PATTERNS = Rails.application.config.x.robots_disallow_patterns
  ROBOTS_DISALLOW_REGEXPS = RobotsUtil.url_patterns_to_regexp(ROBOTS_DISALLOW_PATTERNS)
  ROBOTS_SLOW_SPIDERS = Rails.application.config.x.robots_slow_spiders

  class BadRequestError < TypeError; end

  # For demo, we're using Basic Auth:
  if Rails.configuration.creds[:user_id]
    before_action :authenticate
  end

  def default_url_options(options = {})
    locale = (I18n.locale == I18n.default_locale) ? nil : I18n.locale
    { locale: locale }.merge options
  end

  def route_not_found
    respond_to do |format|
      format.html { render 'error_pages/404', status: :not_found }
      format.all { redirect_to :controller => 'application', :action => 'route_not_found' }
    end
  end

  # robots.txt
  def robots
    respond_to do |format|
      format.text do
        @lang_codes = I18n.available_locales.map { |l| l.to_s }
        if Rails.application.config.x.block_crawlers
          @disallow_patterns = ["/"]
          @slow_spiders = []
        else
          @disallow_patterns = ROBOTS_DISALLOW_PATTERNS
          @slow_spiders = ROBOTS_SLOW_SPIDERS
        end
      end
    end
  end

  def set_breadcrumb_type
    begin
      type = Integer(params[:type])
    rescue TypeError, ArgumentError => e
      raise ActionController::BadRequest.new(e)
    end

    if !BreadcrumbType.values.include? type
      raise ActionController::BadRequest.new("invalid type param: #{type}")
    end

    session[:breadcrumb_type] = type
    flash[:notice] = I18n.t("breadcrumbs.notices.#{BreadcrumbType.to_string(type)}")

    if current_user
      if current_user.update(breadcrumb_type: type)
        logger.debug("Updated user #{current_user.id} breadcrumb type: #{type}")
      else
        logger.error("Failed to update user #{current_user.id} breadcrumb type")
      end
    end

    redirect_to (request.referrer || home_path)
  end

  protected
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == Rails.configuration.creds[:user_id] &&
        password == Rails.configuration.creds[:password]
      end
    end

    def is_admin?
      current_user && current_user.is_admin?
    end

    def is_power_user?
      current_user && current_user.is_power_user?
    end

    def require_user
      raise "Unauthorized" unless current_user
    end

    # https://stackoverflow.com/questions/3297048/403-forbidden-vs-401-unauthorized-http-responses
    def require_admin
      require_user
      raise "Forbidden" unless current_user.is_admin?
    end

    def require_power_user
      require_user
      raise "Forbidden" unless current_user.is_power_user?
    end

    def no_main_container
      @nocontainer = true
    end

    def main_container?
      !@nocontainer
    end

    def breadcrumb_type
      has_breadcrumb = 
        begin 
          current_user && !current_user.breadcrumb_type.blank?
        rescue => e # Shoot, the error doesn't give a class.
          false
        end
      if has_breadcrumb
        current_user.breadcrumb_type
      else
        session[:breadcrumb_type] || BreadcrumbType.default
      end
    end
    helper_method :breadcrumb_type

  public

  # Authorization:
  include Pundit::Authorization
  # TODO: we may want to use :null_session when for the API, when we set that up.
  protect_from_forgery with: :exception

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

  # Devise hooks
  def after_sign_in_path_for(_)
    last_regular_path
  end

  def after_sign_out_path_for(_)
    last_regular_path
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

  def set_last_regular_path
    if !request.xhr? && params[:controller] != "user/sessions" && !params[:controller].start_with?("api") 
      cookies[:last_regular_path] = request.fullpath
    end
  end

  def last_regular_path
    cookies[:last_regular_path] || root_path
  end
end

