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

  def provider
    user = User.from_omniauth(request.env["omniauth.auth"])
    if user.persisted?
      sign_in_and_redirect user, :event => :authentication #this will throw if @user is not activated
      set_flash_message(:notice, :success, :kind => provider) if is_navigational_format?
    else
      session["devise.data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end
  alias_method :twitter, :provider
  alias_method :facebook, :provider
  alias_method :yahoo, :provider
  alias_method :google_oauth2, :provider
  

   
#     
    # auth = request.env["omniauth.auth"]
    # intent = env["omniauth.params"]["intent"] 
    # user = OpenAuthentication.oauth_user_exists?(auth)
    # if intent == "sign_up"
      # if user.blank?
        # redirect_to new_open_authentication_path(info: auth[:info],
         # provider: auth[:provider], uid: auth[:uid])
      # else
        # set_flash_message :notice, :failure, kind: provider,
         # reason: I18n.t(:account_already_linked)
        # redirect_to new_user_registration_path
      # end
    # else 
      # #sign_in
      # if user.blank?
        # redirect_to new_user_session_path
        # set_flash_message :error,  :failure, kind: provider,
            # reason: I18n.t(:account_not_linked)
      # else
        # sign_in_and_redirect user, event: :authentication
        # flash[:notice] =  I18n.t(:signed_in, scope: 'devise.sessions')
      # end
    # end
  # end
  
  
  def failure
    super
  end
end
