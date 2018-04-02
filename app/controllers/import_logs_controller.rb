class ImportLogsController < ApplicationController
  def show
    @log = ImportLog.find(params[:id])
    @resource = @log.resource
    @events = @log.import_events.order("id DESC")
    @events = @events.warns if params[:warns]
    @events = @events.page(params[:page]).per_page(50)
  end
end
