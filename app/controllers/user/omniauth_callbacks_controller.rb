class User::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # GET|POST /resource/auth/twitter
  # def passthru
  #   super
  # end

  # protected

  # The path used when OmniAuth fails
  # def after_omniauth_failure_path_for(scope)
  #   super(scope)
  # end
  def facebook
    user = OpenAuthentication.user_exists?(request.env["omniauth.auth"])
    if user.nil?
      redirect_to open_authentications_new_path(request.env["omniauth.auth"])
    else
      flash.clear
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: 'facebook', 
                              reason: 'this facebook account is already connected')
      redirect_to new_user_registration_path
    end
  end
  
  def twitter
    user = OpenAuthentication.user_exists?(request.env["omniauth.auth"])
    debugger
    if user.nil?
      redirect_to open_authentications_new_path(request.env["omniauth.auth"])
    else
      flash.clear
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: 'twitter', 
                              reason: 'this twitter account is already connected')
      redirect_to new_user_registration_path
    end
  end
  
  def google_oauth2
    user = OpenAuthentication.user_exists?(request.env["omniauth.auth"])
    if user.nil?
      redirect_to open_authentications_new_path(request.env["omniauth.auth"])
    else
      flash.clear
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: 'google', 
                              reason: 'this google account is already connected')
      redirect_to new_user_registration_path
    end
  end
  
  def yahoo
    user = OpenAuthentication.user_exists?(request.env["omniauth.auth"])
    debugger
    if user.nil?
      redirect_to open_authentications_new_path, params: request.env["omniauth.auth"]
    else
      flash.clear
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: 'yahoo', 
                              reason: 'this yahoo account is already connected')
      redirect_to new_user_registration_path
    end
  end
  
  def failure
    super
  end
end
