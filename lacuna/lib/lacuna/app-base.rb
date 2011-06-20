require 'sinatra/oauth2'
require 'rack/auth/oauth2_bearer_token'
require 'lacuna/auth'
require 'lacuna/files'

module Lacuna
  module App
    class Base < Sinatra::Base
      use Rack::Auth::OAuth2BearerToken, 'lacuna' do |token|
        Lacuna::Auth.find_token(token)
      end
      
      helpers do 
        def halt_json(code, response)
          content_type :json
          body response.to_json
          halt code
        end
      end

      helpers Sinatra::OAuth2Helpers
      
      after do
        Lacuna::Files.save
      end
    end
  end
end
