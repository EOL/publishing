class UpdateTermNameI18nPropsJob < ApplicationJob
  def perform
    TermNameTranslationManager.rebuild_node_properties
  end
end
