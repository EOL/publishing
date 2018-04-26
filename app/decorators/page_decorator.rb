class PageDecorator < Draper::Decorator
  include PageDecoratorHelper
  delegate_all
end

