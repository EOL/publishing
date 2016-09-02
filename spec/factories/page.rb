FactoryGirl.define do
  factory :page do
    after(:create) do |page, _|
      page.native_node = create(:native_node, page: page)
      page.save
    end
  end
end
