require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'

module Rack
  module Auth
    class OAuth2BearerToken < AbstractHandler

      def call(env)
        auth = OAuth2BearerToken::Request.new(env)

        if auth.provided? && auth.bearer?
          grant=validate(auth)
          return unauthorized(challenge(:error=>:invalid_token, :error_description=>'Invalid token')) unless grant
          
          env['REMOTE_USER'] = grant['username']
          env['oauth2.token'] = grant
          env['oauth2.token.user'] = grant['username']
          env['oauth2.token.type'] = 'bearer'
          env['oauth2.token.value'] = grant['access_token']
          env['oauth2.token.scopes'] = grant['scopes']
          env['oauth2.token.expires_in'] = grant['expires_in']
        end

        status, headers, body = @app.call(env)
        if status.to_i == 401 || status.to_i == 403
          headers = Utils::HeaderHash.new(headers)

          e, ed, eu, es = env['oauth2.error'], env['oauth2.error.description'], env['oauth2.error.uri'], env['oauth2.error.scope']
          options = {}
          options[:error] = e if e && e.size > 0
          options[:error_description] = ed if ed && ed.size > 0
          options[:error_uri] = eu if eu && eu.size > 0
          options[:scope] = es if es && es.size > 0
          
          auth = headers['WWW-Authenticate']
          if auth && auth.size>0
            auth = challenge(options) + ', ' + auth
          else
            auth = challenge(options)
          end
          headers['WWW-Authenticate'] = auth
        end
        [status, headers, body]
      end


      private

      def challenge(options={})
        options[:realm] = realm
        'Bearer ' + options.map{|k,v| '%s="%s"' % [k,v] }.join(',')
      end

      def validate(auth)
        @authenticator.call(auth.token)
      end

      class Request < Auth::AbstractRequest
        def bearer?
          :bearer == scheme
        end

        def token
          params.split(',').first
        end
      end

    end
  end
end