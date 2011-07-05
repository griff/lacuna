#encoding: utf-8
require 'lacuna/users'
require 'lacuna/auth'
require 'clean_users'

describe Lacuna, 'users' do

  before do
    Lacuna.initialize!
    I18n.locale = 'en'
    #Lacuna.configuration.paths.prefix = '/tmp'
    clean_users
  end
  
  after do
    clean_users
  end

  it "should have one real user" do
    subject.should have(1).real_users
  end

  it "should have one real user named admin" do
    subject.real_users.first.name.should eq('admin')
  end

  it "can create a user" do
    Lacuna.create_user('bro')
    Lacuna.should have(2).real_users
  end
  
  it 'can find admin user' do
    Lacuna.find_user('admin').should_not be_nil
  end

  it 'can find admin user using uid' do
    Lacuna.find_user(1001).should_not be_nil
  end
  
  it "doesn't barf when finding user with Shift_JIS string" do
    Lacuna.find_user("def\xB7".force_encoding("Shift_JIS")).should be_nil
  end
  
  it "fails when deleting user admin" do
    u = Lacuna.find_user('admin')
    expect{ u.remove }.to raise_error(Lacuna::ForbiddenError, 'Adminstrator user can not be deleted')
  end

  it "fails when deleting system user" do
    u = Lacuna.users.first
    expect{ u.remove }.to raise_error(Lacuna::ForbiddenError, 'System users can not be deleted')
  end

  it "fails when creating user with missing name" do
    expect{ Lacuna.create_user(nil) }.to raise_error(Lacuna::BadRequestError, 'User name is missing')
  end

  it "fails when creating user with to short name" do
    expect{ Lacuna.create_user('') }.to raise_error(Lacuna::BadRequestError, 'User name is empty')
  end

  it "fails when creating user with to long name" do
    expect{ Lacuna.create_user('abcdefghijklmnopq') }.to raise_error(Lacuna::BadRequestError, 'User name is to long')
  end

  it "fails when creating user with name that already exists" do
    Lacuna.create_user('bro')
    expect{ Lacuna.create_user('bro') }.to raise_error(Lacuna::ConflictError, 'User name already exists')
  end
  
  it "fails when creating user with 8bit name" do
    expect{ Lacuna.create_user('søren') }.to raise_error(Lacuna::BadRequestError, 'Invalid encoding UTF-8 for user name')
  end

  (0..127).map(&:chr).find_all{|c| !Lacuna.invalid_username_characters.include?(c) }.each do |c|
    it "can create user with valid character #{c.ord}" do
      Lacuna.create_user("ss#{c}ren")
    end
  end

  Lacuna.invalid_username_characters.each do |c|
    it "fails when creating user with invalid character #{c.ord} in name" do
      expect{ Lacuna.create_user("ss#{c}ren") }.to raise_error(Lacuna::BadRequestError, 'Invalid character in user name at position 2')
    end
  end
  
  it "allows creation of utf-8 gecos" do
    u = Lacuna.create_user('bro', :gecos=>'søren')
    u.gecos.should eql("søren")
  end

  (0..127).map(&:chr).find_all{|c| !Lacuna.invalid_gecos_characters.include?(c) }.each do |c|
    it "can create user with valid character #{c.ord} in gecos" do
      Lacuna.create_user("bro", :gecos=>"gr#{c}dd")
    end
  end
  
  Lacuna.invalid_gecos_characters.each do |c|
    it "fails when creating user with invalid character #{c.ord} in gecos" do
      expect{ Lacuna.create_user('bro', :gecos=>"gr#{c}dd") }.to raise_error(Lacuna::BadRequestError, 'Invalid character in user description at position 2')
    end
  end
  
  it "can create a correct user" do
    u = Lacuna.create_user('bro')
    u.uid.should be_between(1000,32000)
    u.real?.should be true
    u.home_dir.should match(%r{^/var/home/})
    u.gid.should eql(`pw groupshow users`.split(':')[2].to_i)
  end
  
  it "creates home directory when asked to" do
    Pathname.new('/var/home/bro').should_not exist
    Lacuna.create_user('bro', :create_home=>true)
    Pathname.new('/var/home/bro').should exist
  end
  
  #it "creates a group matching the username when not explicitly specifying a group" do
  #  `pw showgroup -a`.split("\n").map{|e| e.split(':')[0]}.should_not include('bro')
  #  Lacuna.create_user('bro')
  #  `pw showgroup -a`.split("\n").map{|e| e.split(':')[0]}.should include('bro')
  #end

  it "fails when password is empty" do
    expect{ Lacuna.create_user('bro', :password=>'') }.to raise_error(Lacuna::BadRequestError, 'Password is empty')
  end
  
  it "creates the password correctly" do
    Lacuna.login('bro', 'lacuna').should be(false)
    u = Lacuna.create_user('bro', :password=>'lacuna')
    Lacuna.login('bro', 'lacuna').should be(true)
    Lacuna.login('bro', 'lac').should be(false)
  end

  it "creates a <name>@<domain> user" do
    u = Lacuna.create_user('bro')
    values = Hash[*`userdb -show bro@#{Lacuna.domain}`.split("\n").map{|e| e.split('=', 2) }.flatten]
    values['uid'].should eql(u.uid.to_s)
    values['gid'].should eql(u.gid.to_s)
    values['home'].should eql(u.home_dir)
  end
  
  it "creates the password of the <name>@<domain> user correctly" do
    Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(false)
    Lacuna.create_user('bro', :password=>'lacuna')
    Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(true)
    Lacuna.login("bro@#{Lacuna.domain}", 'lac').should be(false)
  end

  context 'with existing user' do
    
    before do
      Lacuna.create_user('bro', :password=>'lacuna', :create_home=>true)
    end

    subject { Lacuna.find_user('bro') }
    
    it "updates password correctly" do
      subject.password = 'powel'
      subject.commit_changes
      Lacuna.login("bro", 'lacuna').should be(false)
      Lacuna.login("bro", 'powel').should be(true)
    end
  
  
    it "updates password of <name>@<domain> correctly" do
      subject.password = 'powel'
      subject.commit_changes
      Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(false)
      Lacuna.login("bro@#{Lacuna.domain}", 'powel').should be(true)
    end

    it "fails when setting password to nil" do
      expect{ subject.password = nil }.to raise_error(Lacuna::BadRequestError, 'Password is missing')
    end

    it "fails when setting password to empty string" do
      expect{ subject.password = '' }.to raise_error(Lacuna::BadRequestError, 'Password is empty')
    end
    
    it "deletes user" do
      subject.remove
      Lacuna.should have(1).real_users # admin user
    end

    it "deletes user home directory" do
      Pathname.new('/var/home/bro').should exist
      subject.remove
      Pathname.new('/var/home/bro').should_not exist
    end
  end
end