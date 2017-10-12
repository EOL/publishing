  module Api
    class Methods
      VERSION = nil
      BRIEF_DESCRIPTION = nil
      DESCRIPTION = nil
      TEMPLATE = nil
      PARAMETERS = nil

      class << self
        Rails.application.routes.default_url_options[:host] = ActionMailer::Base.default_url_options[:host] || EOL::Server.domain
        include Rails.application.routes.url_helpers # for using user_url(id) type methods

        def brief_description
          call_proc_or_return_value(self::BRIEF_DESCRIPTION)
        end

        def description
          call_proc_or_return_value(self::DESCRIPTION)
        end

        def parameters
          call_proc_or_return_value(self::PARAMETERS)
        end

        def call_proc_or_return_value(proc_or_value)
          return proc_or_value.call if proc_or_value.class == Proc
          proc_or_value
        end

        def method_name
          self.parent.to_s.split("::").last.underscore
        end
        
        #global validations for all input types 
        def validate_and_normalize_input_parameters(input_params)
           parameters.each do |parameter|  #each parameter is type of documentation_parameter
            #each current_value contains the value of parameter which user entered it
            if current_value = input_params[parameter.name.to_sym]
              
              if parameter.integer?
                if is_int? current_value
                  current_value = current_value.to_i
                else
                  current_value=parameter.default
                end
                
              elsif parameter.boolean?
                current_value = convert_to_boolean(current_value)                
                
              elsif parameter.string? && current_value == ""
                current_value= nil
                
              elsif parameter.range?
                current_value = parameter.values.max if current_value > parameter.values.max
                current_value = parameter.values.min if current_value < parameter.values.min
                
              elsif parameter.array?
                current_value.downcase! if current_value.class == String
                current_value = parameter.default unless parameter.values.include?(current_value)
              end
              
              input_params[parameter.name.to_sym]= current_value   
            else
              input_params[parameter.name.to_sym]= parameter.default
            end
            
            if parameter.required? && input_params[parameter.name.to_sym] == nil
              #raise EOL::Exceptions::ApiException.new("Required parameter \"#{documented_parameter.name}\" was not included")
            end
            
           end
        end
        
        def convert_to_boolean(param)
          return false if [ nil, '', '0', 0, 'false', false ].include?(param.downcase)
          true
        end
        
        def is_int? (num)
          begin
            Integer(num)
          rescue
            false # not numeric
          else
            true # numeric
          end
       end

      end
    end
  end