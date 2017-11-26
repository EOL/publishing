FactoryGirl.define do
  factory :collected_page do
    collection
  end
  
  factory :api_collected_page, class: "CollectedPage" do
    collection
    page
    article_ids {create(:api_article).id}
  end
end
