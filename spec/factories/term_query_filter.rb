FactoryGirl.define do
  factory :term_query_filter do
    term_query
    pred_uri "predicate_uri"
    filter_type :predicate

    factory :term_query_filter_object_term do
      filter_type :object_term
      obj_uri "object_term_uri"
    end

    factory :term_query_filter_numeric do
      filter_type :numeric
      num_val1 1.0
      num_op :eq
    end

    factory :term_query_filter_range do
      filter_type :range
      num_val1 1.0
      num_val2 3.0
    end
  end
end
