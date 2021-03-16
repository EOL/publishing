class Admin::DataIntegrityChecksController < AdminController
  def index
    @checks_by_type = DataIntegrityCheck.all_most_recent
  end

  def run
    type = params.require(:type)
    message = DataIntegrityCheck.run(type) ? 'created' : 'already pending'
    flash[:notice]  = message
    redirect_to action: "index"
  end
end
