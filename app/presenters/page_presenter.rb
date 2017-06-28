# TODO: remove. This replaces the ICON, not the name.
class PagePresenter < Blacklight::IndexPresenter
  def label(field_or_string_or_proc, opts = {})
    ActionController::Base.helpers.link_to(document.first(:name), "pages/#{document.first(:id)}")
  end
end
