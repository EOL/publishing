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
    connect(:facebook)
  end
  
  def twitter
    connect(:twitter)
  end
  
  def google_oauth2
    connect(:google)
  end
  
  def yahoo
    connect(:yahoo)
  end
  
  def failure
    super
  end
  
  def connect(provider)
    auth = request.env["omniauth.auth"]
     user = OpenAuthentication.oauth_user_exists?(request.env["omniauth.auth"])
    if user.nil?
      session[:elhash] = auth.info
      redirect_to open_authentications_new_path
    else
      flash.clear
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: provider, 
                              reason: 'this #{provider} account is already connected')
      redirect_to new_user_registration_path
    end
  end
end
