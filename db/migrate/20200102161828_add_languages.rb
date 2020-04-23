class AddLanguages < ActiveRecord::Migration[4.2]
  def change
    Language::Loader.load_file(Rails.root.join('doc', 'new_languages.csv'))
  end
end
