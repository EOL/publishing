# At the time of writing, this was an implementation of
# https://github.com/EOL/eol_website/issues/5#issuecomment-397708511 and
# https://github.com/EOL/eol_website/issues/5#issuecomment-402848623
require "set"

class PageDecorator
  class BriefSummary
    def initialize(page, view)
      @page = page
      @view = view
      @adapter = I18n.locale == I18n.default_locale ? 
        English.new(@page, @view) :
        OtherLanguages.new(@page, @view)
    end

    def result
      @adapter.result
    end
  end
end
