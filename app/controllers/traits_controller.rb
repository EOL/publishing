# Confusingly, this is actually a controller for Uri (q.v.), but we want it
# exposed as "trait", because that's ultimately what it represents. Thus the
# name.
class TraitsController < ApplicationController
  def show
    @uri = Uri.find(params[:id])
  end
end
