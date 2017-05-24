module API
  class Pages
   PARAMS = Proc.new {
      [   
        API::Parameters.new(
          name: 'Boolean',
          type: 'Boolean',
          test_value: false,
          required:  true),
       API::Parameters.new(
          name: 'Int',
          type: 'Integer',
          test_value: 1,
          required:  true),
       API::Parameters.new(
          name: 'Array of Str',
          type: 'String',
          values: ["Test", "String", "Type"],
          required:  true), 
       API::Parameters.new(
          name: 'Range',
          type: 'Integer',
          values: (0..7),
          required:  true), 
      API::Parameters.new(
          name: 'Array',
          type: 'Integer',
          values: [0,1,2,3],
          required:  true) 
        ]
      }
       
       def self.parameters
         self::PARAMS.call
       end
  end
end