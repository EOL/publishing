require 'devise'
class OpenAuthenticationsController < ApplicationController
  def new
    @user = User.new(email: params[:email], password: Devise.friendly_token[0,16],
                     display_name:  params[:name])                
    session[:new_user] = params
  end

  def create
    user = session[:new_user]   
    @user = User.new(email: params[:user][:email], password: Devise.friendly_token[0,16],
                      display_name: user["info"]["name"])
    return render :new  unless @user.valid?
    if user["info"]["email"] == params[:user][:email]
      @user.skip_confirmation!
    end
    @user.save
    @user.after_confirmation
    OpenAuthentication.create(user_id: @user.id, provider: user["provider"], uid: user["uid"])
  end
end
