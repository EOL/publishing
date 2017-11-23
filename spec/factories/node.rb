FactoryGirl.define do
  factory :node do
    resource
    page
    sequence(:canonical_form) { |n| "<i>Scientificus noderi#{(n % 26 + 96).chr}</i>" }
    sequence(:scientific_name) { |n| "#{canonical_form} Bergstrom #{1800 + n}" }
    sequence(:resource_pk)

    factory :native_node, class: "Node" do
      resource { Resource.native }
    end
  end
  
  factory :api_node, class: "Node" do
    resource {create(:api_resource)}
    page
    sequence(:canonical_form) { |n| "<i>Scientificus noderi#{(n % 26 + 96).chr}</i>" }
    sequence(:scientific_name) { |n| "#{canonical_form} Bergstrom #{1800 + n}" }
    sequence(:resource_pk)
  end
end
