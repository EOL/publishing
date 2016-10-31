# I know this is a dangerous class name, since it could very easily collide with
# URI (which is a well-known and widely-used class in Ruby), so I'm not
# delighted with this name and may change it. But for now, CamelCase Uri is
# ours; upper URI is theirs.
module Uri
  class << self
    def is_uri?(url)
      url =~ URI::regexp
    end
  end
end
