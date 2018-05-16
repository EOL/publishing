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

  # def yahoo
    # connect(:yahoo)
  # end

  def failure
    super
  end

  def connect(provider)
    auth = request.env["omniauth.auth"]
    intent = env["omniauth.params"]["intent"]
    user = OpenAuthentication.oauth_user_exists?(auth)
    if intent == "sign_up"
      if user.blank?
        redirect_to new_open_authentication_path(info: auth[:info],
         provider: auth[:provider], uid: auth[:uid])
      else
        set_flash_message :notice, :failure, kind: provider,
         reason: I18n.t(:account_already_linked)
        redirect_to new_user_registration_path
      end
    else
      #sign_in
      if user.blank?
        redirect_to new_user_session_path
        set_flash_message :error, :failure, kind: provider,
            reason: I18n.t(:account_not_linked)
      else
        sign_in_and_redirect user, event: :authentication
        flash[:notice] =  I18n.t(:signed_in, scope: 'devise.sessions')
      end
    end
  end
end
