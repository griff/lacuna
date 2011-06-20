require 'lacuna/mail_users'
require 'test/spec'

describe 'Lacuna mail users' do

  before do
#    File.write
  end

  it "should have no mail users" do
    Lacuna.mail_users.size.should.equal 0
  end

  it "should have no mail users" do
    Lacuna.mail_users.size.should.equal 0
  end
end