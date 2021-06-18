# At the time of writing, this was an implementation of
# https://github.com/EOL/eol_website/issues/5#issuecomment-397708511 and
# https://github.com/EOL/eol_website/issues/5#issuecomment-402848623
require "set"

class PageDecorator
  class BriefSummary
    def initialize(page, view)
      @page = page
      @view = view
    end

    def english
      English.new(@page, @view).result
    end
  end
end
