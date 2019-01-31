class EmptySection
  def position
    Section.maximum(:position) + 1
  end

  def name
    'Other Articles' # TODO: I18n
  end
end
