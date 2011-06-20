require File.expand_path('../boot', __FILE__)

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, ENV['RACK_ENV']) if defined?(Bundler)

