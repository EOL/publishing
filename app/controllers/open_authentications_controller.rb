class OpenAuthenticationsController < ApplicationController
  # prepend_before_action :get_oaoth_params, only: [:create]
  def new
    @user = User.new(email: params[:info][:email],password: Devise.friendly_token[0,16],
                     display_name:  params[:info][:name])
    session[:new_user] = params
  end

  def create
     user = session[:new_user]
     @user = User.new(password: Devise.friendly_token[0,16], display_name: user["info"]["name"])
     # @user.confirm
     # debugger
      if user["info"]["email"] != params[:user][:email]
        @user.confirm
      end
     @user[:email] =  params[:user][:email]
     @user.skip_confirmation! 
     @user.save
     @user.after_confirmation
     OpenAuthentication.create(user_id: @user.id, provider: user["provider"], uid: user["uid"])
  end
  
  # def get_oaoth_params
    # @user = User.new(email: params[:info][:email],password: Devise.friendly_token[0,16],
                     # display_name: params[:info][:name])
    # render :create
    # 
   # debugger
    # @user.confirm! if @user.email != params[:user][:email]
    # @user.update_attribute(email, params[:user][:email])
    # @user.skip_confirmation! 
    # @user.save
    # @user.after_confirmation
    # debugger           
  # 1=t[\]end
end
