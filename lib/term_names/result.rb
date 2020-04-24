class TermNames::Result 
  attr_reader :uri, :value, :options 
  
  def initialize(uri, value, options={})
    @uri = uri
    @value = value
    @options = options
  end
end

