class ImportLogsController < ApplicationController
  def show
    @log = ImportLog.find(params[:id])
  end
end
