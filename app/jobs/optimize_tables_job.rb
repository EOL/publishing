class OptimizeTablesJob < ApplicationJob
  def perform
    Rails.logger.info("START optimize_tables")
    ApplicationRecord.descendants.each do |klass|
      puts "++ #{klass}"
      klass.connection.execute("OPTIMIZE TABLE `#{klass.table_name}`")
    end
    Rails.logger.info("END optimize_tables")
  end
end
