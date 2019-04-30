# Just a place to store a few methods to use and re-use for one-off files that we read for various purposes. They
# usually come from our consults and are thus usually in a predictable format, so we can follow those conventions here.
class DataFile
  class << self
    def to_hash(file, key, options = {})
      data_file = new(file, options)
      data_file.to_hash(key)
    end

    def assume_path(*parts, options)
      new(Rails.root.join('public', 'data', *parts), options)
    end
  end

  def initialize(file, options = {})
    @file = file
    @options = { col_sep: "\t", quote_char: "\x00" }.merge(options)
  end

  def read_tsv
    CSV.read(@file, @options)
  end

  # Given a TSV file where we know one field is always unique, this will read those contents and construct a hash, with
  # the specified key, each value is a hash keyed to the first row (the headers), downcased, underscored and symbolized.
  def to_hash(key)
    dbg("Converting #{@file} to hash...")
    require 'csv'
    # NOTE: I tried the "headers: true" and "forgiving" mode or whatever it was called, but it didn't work. The
    # quoting in this file is really non-conformant (there's one line where there are TWO sets of quotes and that
    # breaks), so I'm just using this "cheat" that I found online where it uses a null for a quote, and I'm building
    # my own hash (inefficiently, but we don't care):
    all_data = CSV.read(@file, @options)
    keys = all_data.shift
    keys.map! { |k| k.underscore.downcase.to_sym }
    hash = {}
    all_data.each do |row|
      row_hash = Hash[keys.zip(row)]
      identifier = row_hash.delete(key)
      raise "DUPLICATE IDENTIFIER! #{identifier}" if hash.has_key?(identifier)
      hash[identifier] = row_hash
    end
    hash
  end

  # Given a TSV file, this will read those contents and construct an array with each member as a hash keyed to the first
  # row (as headers), downcased, underscored and symbolized.
  def to_array_of_hashes(key)
    dbg("Converting #{@file} to hash...")
    require 'csv'
    # NOTE: I tried the "headers: true" and "forgiving" mode or whatever it was called, but it didn't work. The
    # quoting in this file is really non-conformant (there's one line where there are TWO sets of quotes and that
    # breaks), so I'm just using this "cheat" that I found online where it uses a null for a quote, and I'm building
    # my own hash (inefficiently, but we don't care):
    all_data = CSV.read(@file, @options)
    keys = all_data.shift
    keys.map! { |k| k.underscore.downcase.gsub(/\s/, '_').gsub(/[^_\w]/, '').to_sym }
    all_data.map { |row| array << Hash[keys.zip(row)] }
  end
end
