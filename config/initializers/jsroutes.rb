JsRoutes.setup do |config|
  config.exclude = /admin/
  config.module_type = 'UMD'
  config.namespace = 'Routes'
  config.documentation = false
end
