class DataIntegrityCheck < ApplicationRecord
  enum type: {
    circular_relationships: 0,
    same_name_not_synonym: 1,
    ancestry_depth: 2
  }

  enum status: {
    running: 0,
    passed: 1,
    failed: 2
  }
end
