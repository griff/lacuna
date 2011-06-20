#encoding: utf-8
require 'lacuna/users'
require 'lacuna/auth'

describe 'Lacuna users' do

  before do
    Lacuna.initialize!
    #Lacuna.configuration.paths.prefix = '/tmp'
    `pw usershow -a`.force_encoding("ASCII-8BIT").split("\n").each do |u|
      uid = u.split(':')[2].to_i
      next if uid <1000 || uid > 32000
      FileUtils.sh 'pw', 'userdel', uid.to_s
    end
    `userdb -show`.force_encoding("ASCII-8BIT").split("\n").each do |u|
      FileUtils.sh('userdb', u, 'del')
    end
    Dir["#{Lacuna.paths.home_base}/*"].each do |f|
      FileUtils.rm_rf(f)
    end
  end
  
  after do
  end

  it "should have no real users" do
    Lacuna.real_users.should have(0).users
  end

  it "can create a user" do
    Lacuna.create_user('bro')
    Lacuna.real_users.should have(1).user
  end
  
  it "fails when creating user with 8bit name" do
    expect{ Lacuna.create_user('søren') }.to raise_error(ArgumentError)
  end

  it "fails when creating user with invalid name" do
    " ,\t:+&#%$^()!@~*?<>=|\\/\n\r".each_char do |c|
      expect{ Lacuna.create_user("ss#{c}ren") }.to raise_error(ArgumentError)
    end
  end
  
  it "allows creation of utf-8 gecos" do
    u = Lacuna.create_user('bro', :gecos=>'søren')
    u.gecos.should eql("søren")
  end
  
  it "fails when creating user with invalid gecos" do
    ":!@".each_char do |c|
      expect{ Lacuna.create_user('bro', :gecos=>"gr#{c}dd") }.to raise_error(ArgumentError)
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
  
  it "creates the password correctly" do
    Lacuna.login('bro', 'lacuna').should be(false)
    u = Lacuna.create_user('bro', :password=>'lacuna')
    Lacuna.login('bro', 'lacuna').should be(true)
    Lacuna.login('bro', 'lac').should be(false)
  end

  it "creates a bro@<domain> user" do
    u = Lacuna.create_user('bro')
    values = Hash[*`userdb -show bro@#{Lacuna.domain}`.split("\n").map{|e| e.split('=', 2) }.flatten]
    values['uid'].should eql(u.uid.to_s)
    values['gid'].should eql(u.gid.to_s)
    values['home'].should eql(u.home_dir)
  end
  
  it "creates the password of the bro@<domain> user correctly" do
    Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(false)
    Lacuna.create_user('bro', :password=>'lacuna')
    Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(true)
    Lacuna.login("bro@#{Lacuna.domain}", 'lac').should be(false)
  end
  
  it "updates password correctly" do
    u = Lacuna.create_user('bro', :password=>'lacuna')
    Lacuna.login("bro", 'lacuna').should be(true)
    u.password = 'powel'
    u.commit_changes
    Lacuna.login("bro", 'lacuna').should be(false)
    Lacuna.login("bro", 'powel').should be(true)
  end
  
  it "updates password of bro@<domain> correctly" do
    u = Lacuna.create_user('bro', :password=>'lacuna')
    Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(true)
    u.password = 'powel'
    u.commit_changes
    Lacuna.login("bro@#{Lacuna.domain}", 'lacuna').should be(false)
    Lacuna.login("bro@#{Lacuna.domain}", 'powel').should be(true)
  end
end