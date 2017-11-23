FactoryGirl.define do
  factory :content_partner do
    sequence(:name) { |n| "content partner #{n}" }
    description "description test"
    logo { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/pictures-14.jpg"), 'pictures-14/jpg') }
    logoPath "path"
    
    trait :invalid do
      name nil
    end
    
  end
end