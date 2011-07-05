#encoding: utf-8
ENV['RACK_ENV'] = 'test'

require 'lacuna/app/mails'
require 'rack/test'
require 'clean_users'


describe Lacuna::App::Mails do
  include Rack::Test::Methods

  def app
    subject
  end

  def check_json_error(code, tag)
    last_response.status.should be(code)
    last_response.content_type.should eq('application/json')
    body = JSON.parse(last_response.body)
    body['error'].should eq(tag)
  end

  before do
    backup_aliases
  end
  
  after do
    restore_aliases
  end
  
  it 'returns unauthorized when getting actives without token' do
    get '/aliases'
    last_response.status.should be(401)
  end

  it 'returns unauthorized when creating active item without token' do
    post '/aliases', :name=>'knight', :user=>'admin'
    last_response.status.should be(401)
    Lacuna.should have(0).mail_aliases
  end
  
  let(:token) { Lacuna.make_token('admin').token }
  
  context 'with token' do
    before do
      header 'Authorization', "Bearer #{token}"
    end
    
    it 'returns empty list of aliases as json' do
      get '/aliases'
      last_response.status.should be(200)
      last_response.content_type.should eq('application/json')
      JSON.parse(last_response.body).should have(0).items
    end

    it 'creates alias when posting' do
      post '/aliases', :name=>'knight', :user=>'admin'
      last_response.status.should be(201)
      last_response['Location'].should eq('http://example.org/aliases/knight')
      last_response.content_type.should eq('application/json')
      Lacuna.should have(1).mail_aliases
    end

    it 'fails with bad request when name is missing from POST' do
      post '/aliases', :user=>'admin'
      check_json_error(400, 'alias.missing')
    end

    it 'fails with bad request when user is missing from POST' do
      post '/aliases', :name=>'knight'
      check_json_error(400, 'username.missing')
    end

    it 'fails with bad request when user provided with POST does not exist' do
      post '/aliases', :name=>'knight', :user=>'bro'
      check_json_error(400, 'username.unknown')
    end

    it 'fails with bad request when name is empty in POST to /aliases' do
      post '/aliases', :name=>'', :user=>'admin'
      check_json_error(400, 'alias.invalid.empty')
    end

    it 'fails with bad request when name includes 8bit character in POST to /active' do
      post '/aliases', :name=>'søren', :user=>'admin'
      check_json_error(400, 'alias.invalid.bad_encoding')
    end

    it 'fails with bad request when name includes invalid character in POST to /active' do
      post '/aliases', :name=>'s;ren', :user=>'admin'
      check_json_error(400, 'alias.invalid.bad_character')
    end
  end
  
  it 'returns not found when getting unknown alias' do
    get '/aliases/knight'
    last_response.status.should be(404)
  end

  it 'returns "No Content"(204) when deleting unknown alias' do
    delete '/aliases/knight'
    last_response.status.should be(204)
  end

  context 'with existing alias' do
    before do
      Lacuna.create_alias('knight', 'admin')
    end

    it 'returns unauthorized when deleting alias without token' do
      delete '/aliases/knight'
      last_response.status.should be(401)
      Lacuna.should have(1).mail_aliases # check that no alias was deleted
    end

    context 'and token' do
      before do
        header 'Authorization', "Bearer #{token}"
      end

      it 'fails when alias already exists' do
        post '/aliases', :name=>'knight', :user=>'admin'
        check_json_error(409, 'alias.exists')
      end

      it 'get active item' do
        get '/aliases/knight'
        last_response.status.should be(200)
        last_response.content_type.should eq('application/json')
        JSON.parse(last_response.body)['name'].should eq('knight')
      end

      it 'can delete alias' do
        delete '/aliases/knight'
        last_response.status.should be(200)
        Lacuna.should have(0).mail_aliases
      end
    end
  end
end