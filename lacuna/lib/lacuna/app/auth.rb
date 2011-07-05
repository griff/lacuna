require 'sinatra/base'
require 'lacuna/app-base'

class Lacuna::App::Auth < Lacuna::App::Base
  
  helpers do
    def token_json(token)
      {
        :access_token=>token.token,
        :token_type=>:bearer,
        :expires_in=>token.expires_in,
        :scope=>token.scope,
        :refresh_token=>token.token
      }
    end
  end

  post '/token' do
    content_type :json
    halt_json 400, :error=>:invalid_request, :error_details=>:'grant_type.missing' unless params[:grant_type]
    halt_json 400, :error=>:invalid_request, :error_details=>:'client_id.missing' unless params[:client_id]
    halt_json 400, :error=>:invalid_client, :error_details=>:'client_id.invalid' unless params[:client_id] == '1'
    if params[:grant_type] == 'password'
      username = params[:username]
      halt_json 400, :error=>:invalid_request, :error_details=>:'username.missing' unless username
      halt_json 400, :error=>:invalid_request, :error_details=>:'password.missing' unless params[:password]
      scope = params[:scope] || 'all'
      unless Lacuna.login(username,params[:password])
        halt_json 400, :error=>:invalid_grant, :error_details=>:'login.invalid'
      end
      halt_json 400, :error=>:invalid_grant, :error_details=>:'unauthorized_user' unless username == 'admin'
      
      token = Lacuna.make_token(username)
      return token_json(token).to_json
    elsif params[:grant_type] == 'refresh_token'
      halt_json 400, :error=>:invalid_request, :error_details=>:'refresh_token.missing' unless params[:refresh_token]
      token = Lacuna.find_token(params[:refresh_token])
      halt_json 400, :error=>:invalid_request, :error_details=>:'refresh_token.expired' unless token
      token = Lacuna.make_token(token.username)
      return token_json(token).to_json
    else
      halt_json 400, :error=>:unsupported_grant_type, :error_details=>:'grant_type.unsupported' unless token
    end
  end
  
  get '/info' do
    validate_token
    content_type :json
    return token_json(env['oauth2.token']).to_json
  end
end