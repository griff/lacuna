require 'lacuna/setup'
require 'lacuna/users'
require 'lacuna/mail_users'

module Lacuna
  
  def self.mail_aliases
    IO.readlines(paths.aliases).delete_if{|e| e =~ /^\s*#/}.map{|e| MailAlias.new(*e.split(':'))}
  end
  
  def self.find_alias(name)
    mail_aliases.find{|l| l.name == name}
  end
  
  def self.find_user_aliases(user)
    mail_aliases.find_all{|l| l.user == user}
  end
  
  def self.create_alias(name, user)
    raise ArgumentError, "Invalid encoding #{name.encoding.name}" unless name.ascii_only?
    raise ArgumentError, "Invalid character in alias at #{$`.size}" if name =~ /:|!|@|\|/
    raise ArgumentError, "Alias exists" if find_alias(name)
    raise ArgumentError, "Unknown user" unless find_user(user)
    Lacuna::Files.modified << paths.aliases
    File.open(paths.aliases, 'a') {|f| f.puts "#{name}:#{user}" }
    mu = MailUser.new("#{user}@#{Lacuna.domain}")
    Programs.userdb("#{name}@#{Lacuna.domain}", 'set', mu.fields)
    MailAlias.new(name, user)
  end
  
  def self.remove_user_aliases(user)
    raise ArgumentError, "Invalid encoding #{user.encoding.name}" unless user.ascii_only?
    m = Regexp.new(":\s*#{user}\s*$")
    lines = IO.readlines(paths.aliases).delete_if{|l| l =~ m }
    Lacuna::Files.modified << paths.aliases
    File.open(paths.aliases+'.tmp', 'w') {|f| lines.each{|line| f.puts line } }
    Programs.mv(paths.aliases+'.tmp', paths.aliases)
  end
  
  class MailAlias
    attr_reader :name, :user
    
    def initialize(*args)
      @name, @user = args.map{|e| e.strip}
    end
    
    def remove
      m = Regexp.new("^#{name}\s*:")
      lines = IO.readlines(paths.aliases).delete_if{|l| l =~ m }
      Lacuna::Files.modified << paths.aliases
      File.open(paths.aliases+'.tmp', 'w') {|f| lines.each{|line| f.puts line } }
      Programs.mv(paths.aliases+'.tmp', paths.aliases)
    end
  end
end