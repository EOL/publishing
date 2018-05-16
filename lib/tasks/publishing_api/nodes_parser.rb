class NodesParser
  
  properties_filename = "attributes_mapping"
  properties = {}
  
  def load_attributes_mapping    
    File.open(properties_filename, 'r') do |properties_file|
      properties_file.read.each_line do |line|
        line.strip!
        if (line[0] != ?# and line[0] != ?=)
          i = line.index('=')
          if (i)
            properties[line[0..i - 1].strip] = line[i + 1..-1].strip
          else
            properties[line] = ''
          end
        end
      end      
    end
    properties
  end
  
  def self.main_method
    load_attributes_mapping
    properties.each do |key, value|
      puts key + " " + value
    end   
  end
  
end