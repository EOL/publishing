module Reconciliation
  PropertyType = Struct.new(:id) do
    self::ANCESTOR = self.new('ancestor')
    self::RANK = self.new('rank')
    self::CONSERVATION_STATUS = self.new('conservation_status')
    self::EXTINCTION_STATUS = self.new('extinction_status')

    self::ALL = [
      self::ANCESTOR,
      self::RANK,
      self::CONSERVATION_STATUS,
      self::EXTINCTION_STATUS,
    ]
    self::ALL_BY_ID = self::ALL.map { |pt| [pt.id, pt] }.to_h
      

    class << self
      def valid_ids
        self::ALL_BY_ID.keys
      end

      def for_id(id)
        self::ALL_BY_ID[id]
      end

      def id_valid?(id)
        self::ALL_BY_ID.include?(id)
      end
    end

    def name
      I18n.t("reconciliation.property.name.#{id}")
    end

    def description
      I18n.t("reconciliation.property.description.#{id}")
    end

    def to_h
      {
        'id' => id,
        'name' => name
      }
    end
  end
end
