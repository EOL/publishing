class Admin::Db
    class << self
        def optimize_tables
            ApplicationRecord.descendants.each do |klass|
                puts "++ #{klass}"
                klass.connection.execute("OPTIMIZE TABLE `#{klass.table_name}`")
            end
        end
    end
end