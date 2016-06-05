require 'devise'
class OpenAuthenticationsController < ApplicationController
  def new
    @user = User.new(email: params[:info][:email], password: Devise.friendly_token[0,16],
                     username:  params[:info][:name])
    session[:new_user] = params
  end

  def create
     user = session[:new_user]
     @user = User.new(email: params[:user][:email], password: Devise.friendly_token[0,16],
                      username: user["info"]["name"])
     return render :new  unless @user.valid?
     if user["info"]["email"] != params[:user][:email]
       Devise::Mailer.confirmation_instructions(@user, @user.confirmation_token).deliver_now
       flash_msg = I18n.t(:signed_up_but_inactive, scope: 'devise.registrations')
     else
       @user.skip_confirmation!
       flash_msg = I18n.t(:signed_in, scope: 'devise.sessions')
     end

     @user.save
     @user.after_confirmation
     OpenAuthentication.create(user_id: @user.id,
      provider: user["provider"], uid: user["uid"])
     if user["info"]["email"] != params[:user][:email]
       redirect_to new_user_session_path, flash: { notice:  flash_msg }
     else
       sign_in_and_redirect @user, event: :authentication
       flash[:notice] = flash_msg
     end
  end
end
