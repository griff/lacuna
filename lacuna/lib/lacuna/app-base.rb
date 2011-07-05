require 'sinatra/oauth2'
require 'rack/auth/oauth2_bearer_token'
require 'lacuna/base'
require 'lacuna/auth'
require 'lacuna/files'

module Lacuna
  module App
    class Base < Sinatra::Base
      use Rack::Auth::OAuth2BearerToken, 'lacuna' do |token|
        Lacuna.find_token(token)
      end
      
      helpers do 
        def halt_json(code, response)
          content_type :json
          unless response[:error_description]
            error_tag = response[:error_details] || response[:error]
            if code == 400
              e = BadRequestError.new(error_tag)
              response[:error_description] = e.message
            elsif code == 403
              e = ForbiddenError.new(error_tag)
              response[:error_description] = e.message
            elsif code == 409
              e = ConflictError.new(error_tag)
              response[:error_description] = e.message
            else
              e = LacunaTaggedError.new(error_tag)
              response[:error_description] = e.message
            end
          end
          body response.to_json
          halt code
        end
      end

      helpers Sinatra::OAuth2Helpers
      
      after do
        Lacuna::Files.save
      end
      
      error [BadRequestError, ForbiddenError, ConflictError, LacunaTaggedError]  do
        e = env['sinatra.error']
        halt_json e.http_status, :error=>e.tag, :error_description=>e.message
      end
    end
  end
end
