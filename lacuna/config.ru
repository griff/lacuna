require ::File.expand_path('../config/boot',  __FILE__)

Bundler.require(:default, ENV['RACK_ENV'])

require 'lacuna/app'

map '/api' do
  run Lacuna::App::Api
end

map '/api/users' do
  run Lacuna::App::Users
end

map '/api/mails' do
  run Lacuna::App::Mails
end

map '/api/auth' do
  run Lacuna::App::Auth
end

