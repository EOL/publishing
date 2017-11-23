FactoryGirl.define do
  factory :page_content do
    page
    association :content
    source_page_id {page.id}
  end
end