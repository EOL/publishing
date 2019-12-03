class TermI18n
  def self.uri_to_key(uri, prefix = nil)
    uri_part = uri.gsub(".", "(dot)")

    if prefix
      prefix + "." + uri_part
    else
      uri_part
    end
  end
end
