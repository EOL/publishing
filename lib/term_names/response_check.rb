module TermNames::ResponseCheck
  def check_response(response)
    if !response.status.success?
      puts "Got a bad response!"
      puts "Status: #{response.code}"
      puts "Body: #{response.body}"
      puts "Skipping..."
    end
    response.status.success?
  end
end
