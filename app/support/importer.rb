class Importer
  class << self
    def read_clade(file)
      new(file).read_clade
    end
  end

  def initialize(file)
    @file = file
  end

  def read_clade
    raise "File missing!" unless File.exist?(@file)
    require 'tmpdir'
    begin
      create_temp_dir
      extract_files
      read_each_file
    ensure
      rm_temp_dir
    end
  end

  def read_each_file
    require 'csv'
    page_id = File.basename(@file, '.*')
    page_id.sub!('_data', '')
    page_dir = "#{@tmp_dir}/#{page_id}"
    debugger
    integer_like = /\A[0-9]+\Z/
    Dir.foreach(page_dir) do |file|
      next if file == '.' or file == '..'
      next if file =~ /\Atraits/
      next if file =~ /\Ametadata/
      data = CSV.read("#{page_dir}/#{file}")
      table = File.basename(file, '.*')
      fields = data.shift
      klass = Kernel.const_get(table.classify)
      our_fields = klass.column_names
      bad_fields = fields - our_fields
      log("Removing additional columns: #{bad_fields.join(', ')}") unless bad_fields.blank?
      instances = []
      data.each do |row|
        begin
          values = row.map { |v| v =~ integer_like ? v.to_i : v }
          properties = Hash[fields.zip(values)]
          bad_fields.each { |f| properties.delete(f) }
          instance = klass.new(properties)
          instances << instance
        rescue => e
          puts e.message
          debugger
          puts e.class.name
        end
      end
      updatable_fields = fields.dup
      updatable_fields.shift # Remove PK
      updatable_fields -= bad_fields
      updatable_fields.map! { |k| k.to_sym }
      klass.import!(instances, on_duplicate_key_update: updatable_fields)
    end
    TraitBank::Slurp.load_full_csvs(page_dir)
  end

  def create_temp_dir
    @tmp_dir = Dir.mktmpdir('eol-importer-', '/tmp')
  end

  def extract_files
    # NOTE: Using -f wasn't working, so I resorted to a pipe.
    `cd #{@tmp_dir} ; cat #{@file} | /usr/bin/tar xz`
  end

  def rm_temp_dir
    FileUtils.remove_entry(@tmp_dir)
  end

  def log(what)
    # TODO: better logging. For now:
    ts = "[#{Time.now.strftime('%H:%M:%S.%3N')}]"
    puts "** #{ts} #{what}"
    Rails.logger.info("#{ts} IMPORTER: #{what}")
  end
end
