FactoryGirl.define do
  factory :resource do
    #partner
    sequence(:name) { |n| "Resource #{n}" }
    default_language_id "1"
    default_license_string "1"
    dataset_license "1"
    harvest_frequency "once"
    
    trait :invalid do
      name nil
      type "url"
      uploaded_url "https://docs.python.org/2/library/tempfile.html"
    end
    trait :invalid_url do
      type "url"
    end
    
    trait :invalid_file do
      type "file"
      path nil
    end
 
    trait :valid_url do
      type "url"
      uploaded_url "https://docs.python.org/2/library/tempfile.html"
    end
    
    trait :valid_file do
      type "file"
      path { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/test_file"), 'test_file') }
    end
    
    trait :update_no_file_update do
      type "file"
      path nil
    end
    
    trait :update_file_update do
      type "file"
      path  { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/test_file"), 'test_file') }
    end
    
  end

end
