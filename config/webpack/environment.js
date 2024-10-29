const { environment } = require('@rails/webpacker')
const erb = require('./loaders/erb')

environment.config.merge({
  performance: {
    maxEntrypointSize: 300000,
    maxAssetSize: 300000
  }
})

environment.loaders.append('erb', erb)

module.exports = environment
