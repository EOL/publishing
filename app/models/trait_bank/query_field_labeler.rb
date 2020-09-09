class TraitBank::QueryFieldLabeler
  attr_reader :value, :type, :index

  def initialize(field, index)
    @value = field.value
    @type = field.type
    @index = index 
  end

  def label
    @label ||= type.to_s + index.to_s
  end

  def gathered_label
    @gathered_label ||= "gathered_#{label}"
  end

  def gathered_list_label
    @list_label ||= "#{gathered_label}s"
  end

  def tgt_label
    @tgt_label ||= "tgt_#{type}#{index}"
  end
end
