FactoryGirl.define do
  factory :empty_page, class: "Page" do
    factory :page do
      after(:create) do |page, _|
        page.native_node = create(:native_node, page: page)
        page.save
      end
    end
    factory :api_page, class: "Page" do
      page_contents_count 0
      media_count 0
      articles_count 0
      vernaculars_count 1
      scientific_names_count 1
      page_richness 1
      after(:build) do |page|
        page.native_node = create(:api_node, page: page)
        create(:scientific_name, node: page.native_node)
        create(:vernacular, node: page.native_node)
      end
    end
  end
end
