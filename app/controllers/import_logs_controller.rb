class ImportLogsController < ApplicationController
  def show
    @log = ImportLog.find(params[:id])
    @events = @log.import_events.order("id DESC").page(params[:page]).per_page(50)
  end
end
