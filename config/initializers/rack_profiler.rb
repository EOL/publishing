# frozen_string_literal: true

require "rack-mini-profiler"

Rack::MiniProfilerRails.initialize!(Rails.application)

