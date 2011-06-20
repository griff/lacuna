require 'sinatra/base'
require 'lacuna/app-base'
require 'lacuna/users'

class Lacuna::App::Users < Lacuna::App::Base

  helpers do
    def user_json(u)
      {
        :name=>u.name,
        :gecos=>u.gecos,
        :usage=>u.usage,
        :url=>uri('/active/'+u.name, false)
      }
    end
    
    def trash_json(u)
      {
        :name=>u.name,
        :folder=>u.folder,
        :time=>u.time,
        :user=>user_json(u.user),
        :days_to_autodelete=>u.days_to_autodelete,
        :url=>uri('/trash/'+u.folder, false)
      }
    end
  end
  
  get '' do
    # According to RFC 2616 section 14.30, "the field value consists of a
    # single absolute URI"
    response['Location'] = uri('/active')
    halt 301
  end

  get '/active' do
    content_type :json
    Lacuna.real_users.map{|u| user_json(u)}.to_json
  end

  post '/active' do
    name, gecos, pw = params[:name], params[:gecos], params[:password]
    halt_json 400, {:error=>'missing_username', :error_description=>'Brugernavn mangler'} unless name
    name = name.strip
    halt_json 400, {:error=>'invalid_username.to_short', :error_description=>'Brugernavn er for kort'} unless name.size > 0
    halt_json 400, {:error=>'invalid_username.to_long', :error_description=>'Brugernavn er for langt'} unless name.size <= 16
    halt_json 409, {:error=>'username_exists', :error_description=>'Brugernavn existerer allerede'} if Lacuna.find_user(name)
    halt_json 400, {:error=>'missing_password', :error_description=>'Kodeord mangler'} unless pw && pw.size > 0
    gecos = gecos.strip if gecos
    puts "Restore #{params[:restore]} " + (/^.*\/(.*)$/ =~ params[:restore]).inspect
    restore = (params[:restore] =~ /\/([^\/]+)$/) ? $1 : nil
    puts "Restore parsed #{restore}"
    u = Lacuna.create_user(name, :password=>pw, :gecos=>gecos, :create_home=>true, :restore=>restore)

    content_type :json
    data = user_json(u)
    [201, {'Location'=>uri(data[:url],true,false)}, data.to_json];
  end

  get '/active/:id' do
    user = Lacuna.find_user(params[:id])
    not_found unless user && user.real?
    content_type :json
    user_json(user).to_json
  end
  
  put '/active/:id' do
    user = Lacuna.find_user(params[:id])
    not_found unless user && user.real?

    name, pw = params[:name], params[:password]
    halt_json 400, {:error=>'invalid_password', :error_description=>'Kodeord ugyldigt'} if pw && pw.size == 0
    halt_json 400, {:error=>'username_unchangeable', :error_description=>'Brugernavn kan ikke modificeres'} if name && name != user.name

    user.password = pw if pw
    user.gecos = params[:gecos].strip if params[:gecos]
    user.commit_changes
    
    content_type :json
    user_json(user).to_json
  end

  delete '/active/:id' do
    user = Lacuna.find_user(params[:id])
    halt 204 unless user && user.real?
    content_type :json
    user.remove
    user_json(user).to_json
  end

  get '/trash' do
    content_type :json
    Lacuna.user_trash.map{|u| trash_json(u)}.to_json
  end

  get '/trash/:id' do
    trash = Lacuna.user_trash.find{|t| t.folder == params[:id]}
    not_found unless trash
    content_type :json
    trash_json(trash).to_json
  end
  
  delete '/trash/:id' do
    trash = Lacuna.user_trash.find{|t| t.folder == params[:id]}
    halt 204 unless trash
    content_type :json
    trash.remove
    trash_json(trash).to_json
  end
end