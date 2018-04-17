class SearchSuggestionsController < ApplicationController
  layout "application"

  def index
    @search_suggestions = SearchSuggestion.order(:match).by_page(params[:page]).per(50)
  end

  def new
    @search_suggestion = SearchSuggestion.new()
  end

  def create
    @search_suggestion = SearchSuggestion.new(search_suggestion_params)
    if @search_suggestion.save
      flash[:notice] = I18n.t("search_suggestion.created", match: @search_suggestion.match)
      redirect_to search_suggestions_path
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "new"
    end
  end

  def edit
    @search_suggestion = SearchSuggestion.find(params[:id])
  end

  def update
    @search_suggestion = SearchSuggestion.find(params[:id])
    if @search_suggestion.update(search_suggestion_params)
      flash[:notice] = I18n.t("search_suggestion.created", match: @search_suggestion.match)
      redirect_to search_suggestions_path
    else
      # TODO: some kind of hint as to the problem, in a flash...
      render "edit"
    end
  end

  def destroy
    @search_suggestion = SearchSuggestion.find(params[:id])
    @search_suggestion.destroy
    flash[:notice] = I18n.t("search_suggestion.destroyed", match: @search_suggestion.match)
    redirect_to search_suggestions_path
  end

private

  def search_suggestion_params
    params.require(:search_suggestion).permit(:match, :page_id, :synonym_of_id, :object_term, :path, :wkt_string)
  end
end
