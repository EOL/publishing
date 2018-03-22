class DataController < ApplicationController
  helper :data
  protect_from_forgery

  def show
    @data = TraitBank.by_trait(params[:id]).first
    render :layout => false
  end
end
