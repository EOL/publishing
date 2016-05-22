class Users::SessionsController < Devise::SessionsController

prepend_before_action :increment_login_attempts, only: [:new]

  # POST /resource/sign_in
   def create
      if  (session[:login_attempts] > 1 && !verify_recaptcha)
        self.resource = warden.authenticate!(auth_options)
        set_flash_message! :alert, :recaptcha
        flash.delete :recaptcha_error
        clean_up_passwords(resource)
        respond_with_navigational(resource) { render :new }
      else
        super
      end
    end

  private
  def increment_login_attempts
    session[:login_attempts] ||= 0
    session[:login_attempts] += 1
  end
end
