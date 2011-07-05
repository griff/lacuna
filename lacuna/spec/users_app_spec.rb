#encoding: utf-8
ENV['RACK_ENV'] = 'test'

require 'lacuna/app/users'
require 'rack/test'
require 'clean_users'


describe Lacuna::App::Users do
  include Rack::Test::Methods

  def app
    subject
  end

  before do
    clean_users
  end

  after do
    clean_users
  end
  
  def check_json_error(code, tag)
    last_response.status.should be(code)
    last_response.content_type.should eq('application/json')
    body = JSON.parse(last_response.body)
    body['error'].should eq(tag)
  end

  it 'returns unauthorized when getting actives without token' do
    get '/active'
    last_response.status.should be(401)
  end

  it 'returns unauthorized when creating active item without token' do
    post '/active', :name=>'bro'
    last_response.status.should be(401)
    Lacuna.should have(1).real_users
  end
  
  let(:token) { Lacuna.make_token('admin').token }

  context 'with token' do
    before do
      header 'Authorization', "Bearer #{token}"
    end
    
    it 'returns a json array with one item when doing GET on /active' do
      get '/active'
      last_response.status.should be(200)
      last_response.content_type.should eq('application/json')
      JSON.parse(last_response.body).should have(1).items
    end
  
    it 'creates active user when posting' do
      post '/active', :name=>'bro'
      last_response.status.should be(201)
      last_response['Location'].should eq('http://example.org/active/bro')
      last_response.content_type.should eq('application/json')
      Lacuna.should have(2).real_users
    end
    
    it 'fails with bad request when name is missing from POST' do
      post '/active'
      check_json_error(400, 'username.missing')
    end

    it 'fails with bad request when name is empty in POST to /active' do
      post '/active', :name=>''
      check_json_error(400, 'username.invalid.empty')
    end

    it 'fails with bad request when name is to long in POST to /active' do
      post '/active', :name=>'abcdefghijklmnopq'
      check_json_error(400, 'username.invalid.to_long')
    end

    it 'fails with bad request when name includes 8bit character in POST to /active' do
      post '/active', :name=>'søren'
      check_json_error(400, 'username.invalid.bad_encoding')
    end

    it 'fails with bad request when name includes invalid character in POST to /active' do
      post '/active', :name=>'s;ren'
      check_json_error(400, 'username.invalid.bad_character')
    end

    it 'fails with bad request when gecos includes invalid character in POST to /active' do
      post '/active', :name=>'bro', :gecos=>':'
      check_json_error(400, 'gecos.invalid.bad_character')
    end

    it 'can create active user with utf-8 gecos' do
      post '/active', :name=>'bro', :gecos=>'Søren'
      last_response.status.should be(201)
      last_response['Location'].should eq('http://example.org/active/bro')
      last_response.content_type.should eq('application/json')
      Lacuna.should have(2).real_users
    end
  end

  it 'returns not found when getting unknown active user' do
    get '/active/bro'
    last_response.status.should be(404)
  end

  it 'returns not found when putting unknown active user' do
    put '/active/bro'
    last_response.status.should be(404)
  end

  it 'returns "No Content"(204) when deleting unknown active user' do
    delete '/active/bro'
    last_response.status.should be(204)
  end

  context 'with active user' do
    before do
      Lacuna.create_user('bro', :gecos=>'Brian', :password=>'lacuna')
    end
    
    it 'returns unauthorized when putting to active user without token' do
      put '/active/bro', :name=>'bro', :gecos=>'Soeren'
      last_response.status.should be(401)
      Lacuna.find_user('bro').gecos.should eq('Brian') # check that user wasn't changed
    end

    it 'returns unauthorized when deleting active user without token' do
      delete '/active/bro'
      last_response.status.should be(401)
      Lacuna.should have(2).real_users # check that no user was deleted
    end

    context 'and token' do
      before do
        header 'Authorization', "Bearer #{token}"
      end

      it 'fails when user name already exists' do
        post '/active', :name=>'bro'
        check_json_error(409, 'username.exists')
      end

      it 'get active item' do
        get '/active/bro'
        last_response.status.should be(200)
        last_response.content_type.should eq('application/json')
        JSON.parse(last_response.body)['name'].should eq('bro')
      end

      it 'can update active user' do
        put '/active/bro', :name=>'bro', :gecos=>'Soeren', :password=>'anucal'
        last_response.status.should be(200)
        Lacuna.find_user('bro').gecos.should eq('Soeren')
        Lacuna.login('bro', 'anucal').should be_true
      end

      it 'fails with bad request when trying to set empty password' do
        put '/active/bro', :password=>''
        check_json_error(400, 'password.invalid.empty')
      end

      it 'fails with bad request when trying to update user name' do
        put '/active/bro', :name=>'sl'
        check_json_error(400, 'username.unchangeable')
      end

      it 'can delete active user' do
        delete '/active/bro'
        last_response.status.should be(200)
        Lacuna.should have(1).real_users
      end
    end
  end
  
  
  it 'returns unauthorized when getting trashed users without token' do
    get '/trash'
    last_response.status.should be(401)
  end

  it 'returns empty list of trashed users as json' do
    header 'Authorization', "Bearer #{token}"
    get '/trash'
    last_response.status.should be(200)
    last_response.content_type.should eq('application/json')
    JSON.parse(last_response.body).should have(0).items
  end
  
  it 'returns not found when getting unknown trash item' do
    get '/trash/bro'
    last_response.status.should be(404)
  end

  it 'returns "No Content"(204) when deleting unknown trashed user' do
    delete '/trash/bro'
    last_response.status.should be(204)
  end

  context 'with trashed user' do
    before do
      Lacuna.create_user('bro', :create_home=>true).remove
    end
    
    it 'returns unauthorized when getting trashed user without token' do
      get '/trash/bro'
      last_response.status.should be(401)
    end

    it 'returns unauthorized when deleting trashed user without token' do
      delete '/trash/bro'
      last_response.status.should be(401)
    end
    
    context 'and token' do
      before do
        header 'Authorization', "Bearer #{token}"
      end
      
      it 'returns json object for trash item when getting' do
        get '/trash/bro'
        last_response.status.should be(200)
        last_response.content_type.should eq('application/json')
        JSON.parse(last_response.body)['name'].should eq('bro')
      end

      it 'can delete the item' do
        delete '/trash/bro'
        last_response.status.should be(200)
        Lacuna.should have(0).user_trash
      end
    
      it 'can restore trashed user' do
        post '/active', :name=>'sl', :restore=>'/trash/bro'
        last_response.status.should be(201)
        Lacuna.should have(0).user_trash
      end
    end
  end
  
end