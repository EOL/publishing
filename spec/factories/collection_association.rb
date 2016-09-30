FactoryGirl.define do
  factory :collection_association do
    collection
    associated :collection
  end
end
