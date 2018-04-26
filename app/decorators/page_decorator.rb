class PageDecorator < Draper::Decorator
  delegate_all

  def hierarchy
    h.hierarchy(object, true)
  end
end

