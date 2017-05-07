class User::SessionsController < Devise::SessionsController

prepend_before_action :disable_remember_me_for_admins, only: [:create]

SHOW_CAPTCHA_ATTEMPTS = 3

  # GET /resource/sign_in
  # def new
    # super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  private


  def disable_remember_me_for_admins
    admin = User.find_by_email(sign_in_params[:email]).try(:admin?)
    if admin && sign_in_params.has_key?(:remember_me) && sign_in_params[:remember_me]
      set_flash_message! :alert, :sign_in_remember_me_disabled_for_admins
      sign_in_params[:remember_me] = "0"
    end
  end
end
