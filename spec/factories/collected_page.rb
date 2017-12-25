FactoryGirl.define do
  factory :collected_page do
    collection
  end
  
  factory :api_collected_page, class: "CollectedPage" do
    collection
    page
    sequence(:id) {|n| n}
    sequence(:article_ids) { |n| create(:api_article, id: n*300 ).id}
  end
end
