namespace :term_names do
  task refresh_i18n: :environment do
    TermNames.refresh
  end
end

