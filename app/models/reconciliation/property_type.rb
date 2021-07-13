module Reconciliation
  PropertyType = Struct.new(:id) do
    self::ANCESTOR = self.new('ancestor')
    self::RANK = self.new('rank')
    self::ALL = [
      self::ANCESTOR,
      self::RANK
    ]
    self::ALL_BY_ID = self::ALL.map { |pt| [pt.id, pt] }.to_h
      

    class << self
      def valid_ids
        ALL_BY_ID.keys
      end

      def for_id(id)
        ALL_BY_ID[id]
      end

      def id_valid?(id)
        ALL_BY_ID.include?(id)
      end
    end

    def name
      I18n.t("reconciliation.property.name.#{id}")
    end

    def description
      I18n.t("reconciliation.property.description.#{id}")
    end
  end
end
