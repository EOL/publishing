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
  ]

  def initialize(page, view, locale, sentences)
    @page = page
    @view = view
    @tracker = TermTracker.new
    @tagger = TermTagger.new(@tracker, view)
    @helper = Sentences::Helper.new(@tagger, view)
    @locale = locale
    @string = build_string(sentences)
  end

  class << self
    private :new

    def english(page, view)
      new(page, view, :en, ENGLISH_SENTENCES)
    end
  end

  def to_s
    @string
  end

  def terms
    @tracker.result_terms
  end

  private 
  def english
    @english ||= Sentences::English.new(@page, @helper)
  end

  def any_lang
    @any_lang ||= Sentences::AnyLang.new(@page, @helper, @locale)
  end

  def build_string(sentences)
    values = []

    sentences.each do |pair|
      result = self.send(pair.first).send(pair.second)
      values << result.value if result.valid?
    end

    values.join(' ')
  end
end

