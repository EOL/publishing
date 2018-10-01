desc "Generate a boatload of URLs to throw a swarm of tests at"
task test_urls: :environment do
  open(file, 'wb') do |csv|
   Page.where('1=1').limit(10_000).find_each do |page|
     csv << "https://beta.eol.org/pages/#{page.id}\n"
     csv << "https://beta.eol.org/pages/#{page.id}/media\n"
     csv << "https://beta.eol.org/pages/#{page.id}/data\n"
     vern = page.vernaculars&.first&.string
     csv << "https://beta.eol.org/search_results?utf8=%E2%9C%93&q=#{vern}\n" if vern
     csv << "https://beta.eol.org/pages/autocomplete?simple=hash&query=#{page.name[0..3]}\n"
     csv << "https://beta.eol.org/search_results?utf8=%E2%9C%93&q=#{page.name}\n"
     trait = page.data&.first
     if trait
       uri = trait[:predicate][:uri]
       csv << "https://beta.eol.org/terms/#{CGI::escape(uri)}\n"
     end
   end
  end
end
