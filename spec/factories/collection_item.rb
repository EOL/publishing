FactoryGirl.define do
  factory :collection_item do
    collection
    factory(:collected_medum) do
      item { create(:medium) }
    end
  end
end
