class Import::Page
  def from_file(name)
    # Test with name = '/Users/jrice/Downloads/store-328598.json'
    file = File.read(name)
    data = JSON.parse(file)
  end
end
