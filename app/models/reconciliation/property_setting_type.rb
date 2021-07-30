module Reconciliation
  PropertySettingType = Struct.new(:default, :type, :name) do
    self::LIMIT = self.new(0, 'number', 'limit')

    self::ALL = [
      self::LIMIT
    ]

    self::BY_NAME = self::ALL.map { |type| [type.name, type] }.to_h

    def i18n(field)
      I18n.t("reconciliation.property_settings.#{name}.#{field}")
    end

    def label
      i18n(:label)
    end

    def help_text
      i18n(:help_text)
    end
  end
end

