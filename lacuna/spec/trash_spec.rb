#encoding: utf-8
require 'lacuna/trash'
require 'clean_users'

describe Lacuna, 'trash' do
  before do
    Lacuna.initialize!
    I18n.locale = 'en'
    #Lacuna.configuration.paths.prefix = '/tmp'
    backup_aliases
    clean_users
  end
  
  after do
    restore_aliases
    clean_users
  end

  it "has no trash to start with" do
    Lacuna.should have(0).user_trash
  end
  
  it 'fails when trying to restore unknown trash folder' do
    expect { Lacuna.create_user('bro', :restore=>'bro') }.to raise_error(Lacuna::BadRequestError, 'Restore parameter is invalid')
  end

  context 'with deleted user' do

    before do
      @user = Lacuna.create_user('bro', :create_home=>true)
      @group = @user.group
      Lacuna.create_alias('knight', 'bro')
      File.open(File.join(@user.home_dir, 'created_test'), 'w') {|f| f.puts "Testy McTest"}
      @user.remove
    end
    
    it "has a trash item for the deleted user" do
      Lacuna.should have(1).user_trash
      t = Lacuna.user_trash.first
      t.name.should eq(@user.name)
      t.group.should eq(@group.name)
    end

    it "can delete the trashed item" do
      t = Lacuna.find_user_trash('bro')
      t.remove
      Lacuna.should have(0).user_trash
      Pathname.new(t.folder).should_not exist
    end
    
    it "names the trash item folder with the username" do
      Lacuna.find_user_trash('bro').should_not be_nil 
    end

    it "names the trash item folder with the username followed by a number if folder already exists" do
      Lacuna.create_user('bro', :create_home=>true).remove
      Lacuna.find_user_trash('bro-1').should_not be_nil 

      Lacuna.create_user('bro', :create_home=>true).remove
      Lacuna.find_user_trash('bro-2').should_not be_nil 
    end

    it 'can restore user with trash folder as home directory' do
      u = Lacuna.create_user('sl', :restore=>'bro')
      File.read(File.join(u.home_dir, 'created_test')).should eq("Testy McTest\n")
    end

    it 'removes item from trash when restored' do
      Lacuna.create_user('sl', :restore=>'bro')
      Lacuna.should have(0).user_trash
    end
    
    it 'restores any deleted aliases' do
      Lacuna.create_user('sl', :restore=>'bro')
      Lacuna.find_alias('knight').should_not be_nil
    end
  end
  
end