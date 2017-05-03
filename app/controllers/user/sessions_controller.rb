class User::SessionsController < Devise::SessionsController

# prepend_before_action :increment_login_attempts, only: [:new]
# prepend_before_action :check_captcha, only: [:create]
prepend_before_action :disable_remember_me_for_admins, only: [:create]

SHOW_CAPTCHA_ATTEMPTS = 3

  # GET /resource/sign_in
  def new
    # @verify_recaptcha = true if session[:login_attempts] >= SHOW_CAPTCHA_ATTEMPTS
    # logger.info "** Verify: #{@verify_recaptcha}, attempts: #{session[:login_attempts]} > #{SHOW_CAPTCHA_ATTEMPTS}"
    super
  end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  private

  def increment_login_attempts
    session[:login_attempts] ||= 0
    session[:login_attempts] += 1
  end

  def check_captcha
    if session[:login_attempts] >=  SHOW_CAPTCHA_ATTEMPTS && !verify_recaptcha
      set_flash_message! :error, :recaptcha_error, scope: 'devise.failure'
      self.resource = warden.authenticate!(auth_options)
      respond_with_navigational(resource) { render :new }
    else
      true
    end
  end

  def disable_remember_me_for_admins
    admin = User.find_by_email(sign_in_params[:email]).try(:admin?)
    if admin && sign_in_params.has_key?(:remember_me) && sign_in_params[:remember_me]
      set_flash_message! :alert, :sign_in_remember_me_disabled_for_admins
      sign_in_params[:remember_me] = "0"
    end
  end
end
