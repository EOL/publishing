FactoryGirl.define do
  factory :node_ancestor do
    association :ancestor, :factory => :node
    resource_id 1
  end
end
