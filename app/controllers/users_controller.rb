class UsersController < ApplicationController
  before_action :require_admin, only: [:power_user_index, :grant, :revoke]

  def show
    @user = User.find_by!(id: params[:id], active: true)
    # We don't want this page cached by nginx:
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
  end

  def grant
    @user = User.find_by!(id: params[:id], active: true)
    if @user.admin?
      return redirect_to(user_path(@user), notice: "Cannot grant access to admin.")
    else
      @user.grant_power_user
      redirect_to user_path(@user), notice: "Granted power-user privileges for user."
    end
  end

  def revoke
    @user = User.find_by!(id: params[:id], active: true)
    unless @user.power_user?
      return redirect_to(user_path(@user), notice: "This user does not have power-user privileges; nothing to revoke.")
    else
      @user.revoke_power_user
      redirect_to user_path(@user), notice: "Revoked power-user privileges for user."
    end
  end

  def power_user_index
    @users = User.where(role: [User.roles[:power_user], User.roles[:admin]])
    @sort_col = params[:sort_col] || "username"
    @default_sort_dir = "asc"
    @sort_dir = params[:sort_dir] || @default_sort_dir
    @users = @users.order("#{@sort_col} #{@sort_dir}")

    render layout: !request.xhr?
  end

  def autocomplete
    render json: User.autocomplete(params[:query])
  end
end
