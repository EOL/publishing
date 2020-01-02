namespace :term_names do
  task refresh_i18n: :environment do
    adapter_name = ENV['PROVIDER'] ? ENV['PROVIDER'] : nil

    if adapter_name.nil?
      puts "No PROVIDER specified. Do you want to run this task for all providers? 'y' to confirm."
      confirm = STDIN.gets.chomp
      raise "Rerun this task with PROVIDER=<provider_name> to specify a provider. Run `rake term_names:list_providers` to view a list of all available providers" unless confirm == "y"
    end

    TermNames.refresh(adapter_name)
  end

  task list_providers: :environment do
    puts "Available providers:"
    TermNames::ADAPTERS.each do |a|
      puts a.name
    end
  end
end

