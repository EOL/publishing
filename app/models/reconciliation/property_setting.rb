module Reconciliation
  class PropertySetting
    attr_reader :type, :value

    def initialize(type, value)
      unless PropertySettingType::BY_NAME.include?(type)
        raise ArgumentError, "invalid type: #{type}"
      end

      @type = PropertySettingType::BY_NAME[type]
      @value = value # TODO: validate?
    end
  end
end
