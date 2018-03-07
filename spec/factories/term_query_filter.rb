FactoryGirl.define do
  factory :term_query_filter do
    term_query
    pred_uri "predicate_uri"
    op :is_any

    factory :term_query_filter_is_obj do
      op :is_obj
      obj_uri "object_term_uri"
    end
  end
end
