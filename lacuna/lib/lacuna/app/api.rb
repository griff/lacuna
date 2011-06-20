require 'sinatra/base'
require 'lacuna/app-base'

class Lacuna::App::Api < Lacuna::App::Base

  get '' do
    content_type :json
    {
      :mails=>uri('/mails/queue'),
      :mail_aliases=>uri('/mails/aliases'),
      :users=>uri('/users/active'),
      :trash=>uri('/users/trash'),
      :auth=>uri('/auth/token'),
      :token_info=>uri('/auth/info')
    }.to_json
  end

end