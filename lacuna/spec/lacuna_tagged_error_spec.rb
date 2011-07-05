#encoding: utf-8
require 'lacuna/setup'
require 'lacuna/base'

describe Lacuna::LacunaTaggedError do
  before do
    I18n.locale= 'en'
  end
  it "returns tag from tag method" do
    subject.class.new('username.missing').tag.should eq('username.missing')
  end

  it "returns translated message from message method" do
    subject.class.new('username.missing').message.should eq('User name is missing')
  end

  it "returns translated message from to_s method" do
    subject.class.new('username.missing').to_s.should eq('User name is missing')
  end
end