FactoryGirl.define do
  factory :empty_page, class: "Page" do
    factory :page do
      after(:create) do |page, _|
        page.native_node = create(:native_node, page: page)
        page.save
      end
    end
  end
end
