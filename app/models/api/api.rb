module Api
  METHODS = [ :pages ]
  def self.default_version_of(method)
      begin
        method_class = "Api::#{method.to_s.camelize}".constantize
        "#{method_class}::V#{method_class::DEFAULT_VERSION.tr('.', '_')}".constantize
      rescue
        return nil
      end
  end
end