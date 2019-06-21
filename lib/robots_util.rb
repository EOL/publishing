class RobotsUtil
  # convert robots.txt style url prefix patterns (may include wildcard *) to regexps.
  def self.url_patterns_to_regexp(patterns)
    patterns.collect do |pattern|
      is_dir = pattern.end_with? "/"
      regexp_str = "^#{pattern.split("*").collect { |part| Regexp.escape(part) }.join(".*")}#{is_dir ? "" : "$"}"
      Regexp.new regexp_str
    end
  end
end
