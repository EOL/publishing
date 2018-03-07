class ArticlesController < ApplicationController
  layout "application"

  def show
    @article = Article.where(id: params[:id]).includes(:license,
      :bibliographic_citation, :location, attributions: :role).first
  end
end
