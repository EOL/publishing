# Allows us some way to choose which resources are "best" at providing various types of data, so we can "weigh" those
# resources more heavily in sorting.
class ResourcePreference < ApplicationRecord
  belongs_to :resource

  acts_as_list scope: [:class_name]

  # Return a hash where keys are resource_ids and values are their preference (lower is "better"). e.g.: { 123 => 1, 234
  # => 2, 345 => 3, 456 => 4 }. Note that the default value is the "worst" score, e.g.: `hash[999] # => 5`
  def self.hash_for_class(class_name)
    # NOTE I'm passing *index* here instead of *position*, so we can count on the return hash being sequential.
    by_class = where(class_name: class_name).order(:position)
    hash = Hash.new(by_class.count + 1)
    by_class.each_with_index do |pref, index|
      hash[pref.resource_id] = index
    end
    hash
  end
end
