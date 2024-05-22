const { merge } = require('webpack-merge');

process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const baseConfig = require('./base')

const prodConfig = {
  mode: 'production'
}

module.exports = merge(baseConfig, prodConfig)
