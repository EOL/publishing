class ReconciliationResult
  PropertyType = Struct.new(:id, :name, :description) do
    self::ANCESTOR = self.new('ancestor', 'Ancestor', 'A taxon which is an ancestor of the taxon being queried for')
    self::RANK = self.new('rank', 'Rank', "A string representing the rank of the taxon under query, e.g., 'species', 'genus', etc.")
    self::ALL = [
      self::ANCESTOR,
      self::RANK
    ]
  end
end
