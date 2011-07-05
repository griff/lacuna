require 'sinatra/base'

module Sinatra
  module OAuth2Helpers
    def unauthorized(options={})
      env['oauth2.error'] = options[:error]
      env['oauth2.error.description'] = options[:error_description]
      env['oauth2.error.uri'] = options[:error_uri]
      env['oauth2.error.scope'] = options[:scope]
      halt 401
    end
    
    def forbidden(options={})
      env['oauth2.error'] = options[:error]
      env['oauth2.error.description'] = options[:error_description]
      env['oauth2.error.uri'] = options[:error_uri]
      env['oauth2.error.scope'] = options[:scope]
      halt 403
    end
    
    def has_token?
      !env['oauth2.token.value'].nil?
    end
    
    def validate_token(required_scope=nil)
      unauthorized(:scope=>required_scope) unless has_token?
    end
    
    def require_scope(scope)
      require_scopes(*scope.split(' '))
    end
    
    def require_scopes(*scopes)
      validate_token(scopes.join(' '))
      unless scopes.all?{|s| env['oauth2.token.scopes'].include?(s)}
        forbidden(:scope=>scopes.join(' '), :error=>:insufficient_scope)
      end
    end
  end
  
  helpers OAuth2Helpers
end