FactoryGirl.define do
  factory :collection_association do
    collection
    associated, factory: :collection
  end
end
