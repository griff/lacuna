require 'lacuna/fileutils'

module Lacuna
  def self.mail_users
    Programs.capture(:userdb, '-show').split("\n").map{|u| MailUser.new(u)}
  end
  
  def self.mail_user(name)
    MailUser.new(name)
  end
  
  def self.create_mail_user(name, password)
    vmail = find_user('vmail')

    FileUtils.mkdir_p("#{vmail.home_dir}/#{name}")
    Programs.userdb(name, 'set', :uid=>vmail.uid, :gid=>vmail.gid, :mail=>"#{vmail.home_dir}/#{name}/Maildir", :home=>vmail.home_dir, :password=>password)
    Programs.maildirmake("#{vmail.home_dir}/#{name}/Maildir")
  end
  
  class MailUser
    attr_reader :name, :fields
    
    def initialize(name)
      @name = name
      @fields={}
      Programs.capture(:userdb, '-show', name).split("\n").each do |l|
        key, value = l.split('=')
        fields[key.to_sym] = value
      end
    end
    
    def uid() fields[:uid] end
    def gid() fields[:gid] end
    def mail() fields[:mail] end
    def home() fields[:home] end
    def systempw() fields[:systempw] end
    
    def remove
      Programs.userdb(name, 'del') &&
        (mail.nil? || FileUtils.rm_rf(mail, :secure=>true))
    end
  end
end