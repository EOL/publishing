class Importer
  class << self
    def read_clade(file, options = {})
      new(file, options).read_clade
    end
  end

  def initialize(file, options = {})
    @file = file
    @skip_known_terms = options[:skip_known_terms] || false
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
    integer_like = /\A[0-9]+\Z/
    has_traits = false
    has_terms = false
    Dir.foreach(@page_dir) do |file|
      next if file == '.' || file == '..'
      if file =~ /\Atraits/
        has_traits = true
        puts "Skipping (for the moment) the traits file. *************************************************************"
        next
      end
      if file =~ /\Ametadata/
        has_traits = true
        puts "Skipping (for the moment) the metadata file. *************************************************************"
        next
      end
        if file =~ /\Aterms/
        has_terms = file
        puts "Skipping (for the moment) the terms file. *************************************************************"
        next
      end
      log("Reading #{file}...")
      data = CSV.read("#{@page_dir}/#{file}")
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
      results = klass.import!(instances, on_duplicate_key_update: updatable_fields)
      log(results.inspect)
    end
    # NOTE: you have to read terms BEFORE traits, or they will fail (because it cannot build relationships to terms)!
    read_terms_if_needed(has_terms)
    read_traits_if_needed(has_traits)
  end

  def read_terms_if_needed(has_terms)
    if has_terms
      log("Reading terms...")
      read_terms("#{@page_dir}/#{has_terms}")
      log("Read terms.")
    else
      log("NO TERMS; skipping.")
    end
  end

  def read_traits_if_needed(has_traits)
    if has_traits
      log("Reading traits...")
      # neo4j can't read a file (?!?), so we have to provide a URL, which means **** YOUR SERVER MUST BE RUNNING. ****
      # ...and we have to copy the files into place:
      traits_filename = Rails.root.join('public', "traits_#{@page_id}.csv")
      metadata_filename = Rails.root.join('public', "meta_traits_#{@page_id}.csv")
      begin
        FileUtils.copy_file("#{@page_dir}/traits.csv", traits_filename)
        FileUtils.copy_file("#{@page_dir}/metadata.csv", metadata_filename) if File.exist?("#{@page_dir}/metadata.csv")
        TraitBank::Slurp.load_full_csvs(@page_id)
      ensure
        FileUtils.rm(traits_filename)
        FileUtils.rm(metadata_filename) if File.exist?(metadata_filename)
      end
      log("Read traits.")
    else
      log("NO TRAITS; skipping.")
    end
  end

  def read_terms(file)
    importer = Term::Importer.new(skip_known_terms: @skip_known_terms)
    data = CSV.read(file)
    fields = data.shift
    data.each do |values|
      properties = Hash[fields.zip(values)]
      importer.from_hash(properties)
    end
    new_terms = importer.new_terms
    if new_terms.size > 100 # Don't bother saying if we didn't have any at all!
      log("There were #{new_terms.size} new terms, which is too many to show.")
    else
      log("New terms: #{new_terms.join("\n  ")}")
    end
    log("Finished importing terms: #{new_terms.size} new, #{importer.knew} known, #{importer.skipped} skipped.")
  end

  def create_temp_dir
    @tmp_dir = Dir.mktmpdir('eol-importer-', '/tmp')
    @page_id = File.basename(@file, '.*')
    @page_id.sub!('_data', '')
    @page_dir = "#{@tmp_dir}/#{@page_id}"
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
