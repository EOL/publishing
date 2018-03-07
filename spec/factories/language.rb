FactoryGirl.define do
  # NOTE: this is only *guaranteed* to work for 26 languages, so if we need more
  # than that for testing, this code will have to change!
  factory :language do
    sequence(:group) do |n|
      first = "mtoaenjrblupywdkghqvzsfcix"
      second = "lfqwoiknxjgumchszprvtyadeb"
      "#{first[n]}#{second[n]}"
    end
    
    sequence(:code) do |n|
      third = "euqnhvziafdpjtomclrgbxkysw"
      "#{group}#{third[n]}"
    end
  end
end
