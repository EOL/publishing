class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    redirect_if_user_is_inactive
  end

  def index
    @dummy = "HOME"
    @users = User.all
  end

  def delete_user
    @user = User.find(params[:id])
    if @user && current_user.try(:can_delete_account?, @user)
      @user.soft_delete
      Devise.sign_out_all_scopes ? sign_out : sign_out(User)
      flash[:notice] = I18n.t(:destroyed, scope: 'devise.registrations')
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json { render json: true }
      end
    end
  end

  def search
    q = User.search do
      fulltext params[:q] do
        highlight :name
        highlight :username
      end
      field_list [:name, :username]
      paginate page: params[:page] || 1, per_page: params[:per_page] || 30
    end
    matches = {}
    users = {}
    results = []
    q.hits.each do |hit|
      [:name, :username].each do |field|
        hit.highlights(field).compact.each do |highlight|
          word = highlight.format { |word| word }
          word = word.downcase
          unless matches.has_key?(word) || users.has_key?(hit.primary_key)
            results << { value: word, tokens: word.split, id: hit.primary_key }
            matches[word] = true
            users[hit.primary_key] = true
          end
        end
      end
    end
    render json: JSON.pretty_generate(results)
  end

  private

  def redirect_if_user_is_inactive
    unless @user.active
      flash[:notice] = I18n.t(:user_not_active)
      redirect_to new_user_session_path
    end
  end
end
