FactoryGirl.define do
  factory :collection_item do
    collection
    
    factory :collected_page do
      association :item, factory: :page
    end
  end
end
