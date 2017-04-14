class TraitsController < ApplicationController
  helper :traits
  protect_from_forgery

  def show
    respond_to do |format|
      @trait = TraitBank.by_trait(params[:id]).first
      format.js { }
    end
  end
end
