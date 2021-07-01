class BriefSummary
  ENGLISH_SENTENCES = [
    [:any_lang, :family_and_above_taxonomy],
    [:english, :descendants], 
    [:english, :first_appearance],
    [:english, :below_family_taxonomy],
    [:english, :is_an_x_growth_form],
    [:english, :has_an_x_growth_form],
    [:any_lang, :extinction],
    [:english, :conservation],
    [:any_lang, :marine],
    [:any_lang, :freshwater],
    [:english, :native_range],
    [:english, :found_in],
    [:english, :landmark_children],
    [:english, :plant_description],
    [:english, :visits_flowers],
    [:english, :flowers_visited_by],
    [:any_lang, :fix_nitrogen],
    [:english, :form1],
    [:english, :form2],
    [:english, :ecosystem_engineering],
    [:english, :behavior],
    [:english, :lifespan_size],
    [:english, :reproduction_vw],
    [:english, :reproduction_y],
    [:english, :reproduction_x],
    [:english, :reproduction_z],
    [:english, :motility]
  ].map { |pair| BriefSummary::Result::SentenceSpec.new(pair.first, pair.second) }

  class << self
    def english(page, view)
      BriefSummary::Result.new(page, view, ENGLISH_SENTENCES, :en) 
    end
  end
end

