require File.expand_path('../boot', __FILE__)

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
envs = ENV['RACK_ENV'].nil? ? [:default] : [:default, ENV['RACK_ENV']]
Bundler.require(*envs) if defined?(Bundler)

