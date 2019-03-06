class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    redirect_if_user_is_inactive
  end

  def autocomplete
    render json: User.autocomplete(params[:query])
  end

  private

  def redirect_if_user_is_inactive
    unless @user.active
      flash[:notice] = I18n.t(:user_not_active)
      redirect_to new_user_session_path
    end
  end
end
