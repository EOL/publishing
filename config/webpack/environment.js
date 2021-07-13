const { environment } = require('@rails/webpacker')

environment.config.merge({
  performance: {
    maxEntrypointSize: 300000,
    maxAssetSize: 300000
  }
})

module.exports = environment
