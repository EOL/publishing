class VernacularsController < ApplicationController
  def prefer
    name = Vernacular.find(params[:id])
    authorize name
    Vernacular.transaction do
      name.page.vernaculars.where(language_id: name.language_id).update_all(is_preferred: false)
      name.update_attribute(:is_preferred, true)
    end
    flash[:notice] = I18n.t("names.preferred_in_language_for_page", language: I18n.t("languages.#{name.language.group}"), page: name.page.scientific_name, name: name.string)
    redirect_to(page_names_path(name.page))
  end
end
