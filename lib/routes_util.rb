class RoutesUtil
  def self.path_with_locale(path_format, param_keys)
    Proc.new do |path_params, _|
      base_path = sprintf(path_format, *(param_keys.collect { |k| path_params[k] }))
      if path_params[:locale].blank?
        base_path
      else
        "/#{path_params[:locale]}#{base_path}"
      end
    end 
  end
end
