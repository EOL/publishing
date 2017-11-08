xml.instruct! :xml, :encoding => "UTF-8", :standalone => "yes"

xml.response do                                                                                                               
  unless error.blank?
    xml.error do
      xml.message error
    end
  end
end