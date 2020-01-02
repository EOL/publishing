class User::RegistrationsController < Devise::RegistrationsController
  prepend_before_action :check_captcha, only: [:create]
  prepend_before_action :configure_sign_up_params, only: [:create]
  prepend_before_action :configure_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  #PUT /resource
  #def update
  #  super
  #end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  def configure_update_params
    devise_parameter_sanitizer.permit(:account_update) do |u|
      u.permit(
        :email,
        :username,
        :bio,
        :password,
        :password_confirmation,
        :current_password
      )
    end
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up)do |u|
      u.permit( :username,:email, :password, :password_confirmation, :age_confirm, :tou_confirm)
    end
  end
  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.for(:account_update) << :attribute
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end

  def after_update_path_for(resource)
    user_path(resource)
  end

  private

  def check_captcha
    if verify_recaptcha
      true
    else
      self.resource = User.new(sign_up_params)
      resource.valid?
      resource.errors.add(:recaptcha, I18n.t(:recaptcha_error))
      render :new 
    end 
  end
end
