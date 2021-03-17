class DataIntegrityCheck < ApplicationRecord
  validates_presence_of :type
  validates_presence_of :status

  enum type: {
    circular_relationships: 0,
    same_name_not_synonym: 1,
    term_ancestry_height: 2
  }

  enum status: {
    pending: 0,
    running: 1,
    passed: 2,
    failed: 3,
    errored: 4,
    warned: 5,
  }

  TYPES_TO_CLASSES = {
    circular_relationships: DataIntegrityCheck::CircularRelationships,
    same_name_not_synonym: DataIntegrityCheck::SameNameNotSynonym,
    term_ancestry_height: DataIntegrityCheck::TermAncestryHeight
  }

  class << self
    # 'type' column is reserved for polymorphic associations unless this is overridden
    def inheritance_column
      'none'
    end

    def all_most_recent
      types.map do |k, v|
        { type: k, record: self.where(type: v).order('created_at DESC').limit(1)&.first }
      end
    end

    def run(type)
      type = type.to_sym
      raise TypeError, "invalid type: #{type}" unless types.symbolize_keys.include?(type)
      pending = self.where(type: type, status: [:pending, :running])&.first

      return false if pending

      new = self.create!(type: type, status: :pending)
      new.background_run_with_delay
      true
    end
  end

  def background_run
    update!(started_at: Time.now)

    begin
      result = TYPES_TO_CLASSES[type.to_sym].new.run
      status = result.status
      message = result.message
    rescue => e 
      status = :errored
      message = e.message
    end

    update!(status: status, message: message, completed_at: Time.now)
  end
  handle_asynchronously :background_run, queue: 'data_integrity'
end
