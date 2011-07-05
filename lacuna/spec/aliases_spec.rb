#encoding: utf-8
require 'lacuna/aliases'
require 'clean_users'

describe Lacuna, 'aliases' do

  before do
    Lacuna.initialize!
    I18n.locale = 'en'
    backup_aliases
    clean_users
  end
  
  after do
    restore_aliases
    clean_users
  end
  
  it 'should have no mail aliases' do
    Lacuna.should have(0).mail_aliases
  end
  
  it "can create an alias" do
    Lacuna.create_alias('root', 'admin')
    Lacuna.should have(1).mail_aliases
    Lacuna.find_alias('root').should_not be_nil
    Lacuna.find_user_aliases('admin').should have(1).item
  end

  it "fails when creating alias with missing name argument" do
    expect{ Lacuna.create_alias(nil, 'bro') }.to raise_error(Lacuna::BadRequestError, 'Alias is missing')
  end

  it "fails when creating alias with missing user argument" do
    expect{ Lacuna.create_alias('root', nil) }.to raise_error(Lacuna::BadRequestError, 'User name is missing')
  end

  it "fails when creating alias to non-existing user" do
    expect{ Lacuna.create_alias('root', 'bro') }.to raise_error(Lacuna::BadRequestError, 'Unknown user')
  end

  it "fails when creating alias with empty name" do
    expect{ Lacuna.create_alias('', 'admin') }.to raise_error(Lacuna::BadRequestError, 'Alias is empty')
  end

  it "fails when creating alias with name that already exists" do
    Lacuna.create_alias('root', 'admin')
    expect{ Lacuna.create_alias('root', 'admin') }.to raise_error(Lacuna::ConflictError, 'Alias already exists')
  end

  it "fails when creating alias with 8bit user" do
    expect{ Lacuna.create_alias('root', 'søren') }.to raise_error(Lacuna::BadRequestError, 'Invalid encoding UTF-8 for user name')
  end
  
  it "fails when creating alias with 8bit name" do
    expect{ Lacuna.create_alias('søren', 'admin') }.to raise_error(Lacuna::BadRequestError, 'Invalid encoding UTF-8 for alias')
  end

  (0..127).map(&:chr).find_all{|c| !Lacuna.invalid_alias_characters.include?(c) }.each do |c|
    it "can create alias with valid character #{c.ord} in name" do
      Lacuna.create_alias("ss#{c}ren", 'admin')
    end
  end

  Lacuna.invalid_alias_characters.each do |c|
    it "fails when creating alias with invalid character #{c.ord} in name" do
      expect{ Lacuna.create_alias("ss#{c}ren", 'admin') }.to raise_error(Lacuna::BadRequestError, 'Invalid character in alias at position 2')
    end
  end
  
  context "with a user" do
    before do
      Lacuna.create_user('bro', :password=>'lacuna')
    end
    
    it "can use alias for login" do
      Lacuna.login("paula.shore@#{Lacuna.domain}", 'lacuna').should be_false
      Lacuna.create_alias('paula.shore', 'bro')
      Lacuna.login("paula.shore@#{Lacuna.domain}", 'lacuna').should be_true
    end
  
    context "with existing alias" do
      before do
        @user = Lacuna.create_alias('paula.shore', 'bro')
      end
    
      subject { Lacuna.find_alias('paula.shore') }
    
      it "deletes alias" do
        subject.remove
      end
    
      it "also deletes the login" do
        Lacuna.login("paula.shore@#{Lacuna.domain}", 'lacuna').should be_true
        subject.remove
        Lacuna.login("paula.shore@#{Lacuna.domain}", 'lacuna').should be_false
      end
      
      it "deletes alias when deleting user" do
        @user.remove
        Lacuna.find_alias('paula.shore').should be_nil
      end

      it "deletes alias login when deleting user" do
        Lacuna.login("paula.shore@#{Lacuna.domain}", 'lacuna').should be_true
        @user.remove
        Lacuna.login("paula.shore@#{Lacuna.domain}", 'lacuna').should be_false
      end
    end
  end

end