Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '/api/reconciliation*', headers: :any, methods: [:get, :post]
  end
end
