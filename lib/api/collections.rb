module API
  class Collections
   PARAMS = Proc.new {
      [   
        API::Parameters.new(
          name: 'Boolean_Collection',
          type: 'Boolean',
          test_value: false,
          required:  true),
       API::Parameters.new(
          name: 'Int_Collection',
          type: 'Integer',
          test_value: 1,
          required:  true),
       API::Parameters.new(
          name: 'Str_Collection',
          type: 'String',
          values: "Test, String, Type",
          required:  true), 
       API::Parameters.new(
          name: 'Range_Collection',
          type: 'Integer',
          values: (0..7),
          required:  true), 
      API::Parameters.new(
          name: 'Array_Collection',
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