FactoryGirl.define do
  factory :resource do
    #partner
    #sequence(:name) { |n| "Resource #{n}" }
    name "resource_test"
    default_language_id "1"
    default_license_string "1"
    dataset_license "1"
    harvest_frequency "once"
    
    trait :invalid do
      name nil
    end
    trait :invalid_url do
      type "url"
    end
    
    trait :invalid_file do
      type "file"
    end
    
    trait :valid_url do
      type "url"
      uploaded_url "https://docs.python.org/2/library/tempfile.html"
    end
    
    trait :valid_file do
      type "file"
    end
  end

end
