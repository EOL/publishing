class AddLanguages < ActiveRecord::Migration
  def change
    require 'csv'
    CSV.foreach(Rails.root.join('doc', 'new_languages.csv')) do |line|
      next if line[2].blank? # No language name, have to skip it.
      if Language.where(code: line[0]).exists?
        lang = Language.find_by_code(line[0])
        lang.group = line[1]
        lang.save!
      else
        Language.create(code: line[0], group: line[1], can_browse_site: false)
      end
    end
  end
end
