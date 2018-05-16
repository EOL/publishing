class ImportLogsController < ApplicationController
  def show
    @log = ImportLog.find(params[:id])
    @resource = @log.resource
    @events = @log.import_events.order("id DESC")
    @events = @events.warns if params[:warns]
    @events = @events.by_page(params[:page]).per(50)
  end
end
