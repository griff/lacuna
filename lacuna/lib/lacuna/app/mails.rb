require 'sinatra/base'
require 'lacuna/app-base'
require 'lacuna/mail'
require 'lacuna/mail_users'

class Lacuna::App::Mails < Lacuna::App::Base

  helpers do
    def mail_json(m)
      {
        :queue_time=>m.queue_time, 
        :size=>m.size, 
        :id=>m.id, 
        :from=>m.from, 
        :to=>m.to,
        :frozen=>m.frozen?,
        :log=>m.log,
        :url=>uri('/queue/'+m.id, false),
        :thaw_url=>uri('/queue/frozen/'+m.id, false),
        :freeze_url=>uri('/queue/active/'+m.id, false)
      }
    end

    def mail_user_json(u)
      {
        :name=>u.name,
        :domain=>u.domain,
        :url=>uri('/users/'+u.name, false)
      }
    end
    
    def mail_alias_json(l)
      {
        :name=>l.name,
        :user=>l.user,
        :url=>uri('/aliases/'+l.name, false)
      }
    end
  end

  get '/queue' do
    require_scope 'all'
    content_type :json
    Lacuna.mails.map {|m| mail_json(m)}.to_json
  end

  get '/queue/:id' do
    m = Lacuna.find_mail(params[:id])
    not_found unless m
    require_scope 'all'
    content_type :json
    mail_json(m).to_json
  end

  delete '/queue/:id' do
    mail = Lacuna.find_mail(params[:id])
    halt 204 unless mail
    require_scope 'all'
    content_type :json
    mail.remove
    mail_json(mail).to_json
  end

  delete '/queue/frozen/:id' do
    mail = Lacuna.find_mail(params[:id])
    halt 204 unless mail && mail.frozen?
    require_scope 'all'
    content_type :json
    mail.thaw
    mail_json(mail).to_json
  end

  delete '/queue/active/:id' do
    mail = Lacuna.find_mail(params[:id])
    halt 204 unless mail && !mail.frozen?
    require_scope 'all'
    content_type :json
    mail.freeze
    mail_json(mail).to_json
  end
  
  get '/aliases' do
    require_scope 'all'
    content_type :json
    Lacuna.mail_aliases.map {|m| mail_alias_json(m)}.to_json
  end
  
  post '/aliases' do
    require_scope 'all'
    name, user = params[:name], params[:user]
    #halt_json 400, {:error=>'missing_username', :error_description=>'Brugernavn mangler'} unless user
    #halt_json 400, {:error=>'missing_alias', :error_description=>'Alias mangler'} unless name
    name = name.strip if name
    user = user.strip if user
    
    #halt_json 400, {:error=>'unknown_user', :error_description=>'Ukendt bruger'} unless Lacuna.find_user(user)
    #halt_json 409, {:error=>'alias_exists', :error_description=>'Alias existerer allerede'} if Lacuna.find_alias(name)

    Lacuna.create_alias(name, user)

    content_type :json
    data = mail_alias_json(Lacuna.find_alias(name))
    [201, {'Location'=>uri(data[:url],true,false)}, data.to_json];
  end
  
  get '/aliases/:id' do
    a = Lacuna.find_alias(params[:id])
    not_found unless a
    require_scope 'all'
    content_type :json
    mail_alias_json(a).to_json
  end
  
  delete '/aliases/:id' do
    a = Lacuna.find_alias(params[:id])
    halt 204 unless a
    require_scope 'all'
    content_type :json
    a.remove
    mail_alias_json(a).to_json
  end
  
end