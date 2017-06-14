class DataController < ApplicationController
  helper :data
  protect_from_forgery

  def show
    respond_to do |format|
      @data = TraitBank.by_trait(params[:id]).first
      format.js { }
    end
  end
end
