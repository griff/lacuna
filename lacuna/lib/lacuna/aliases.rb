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
  
  def self.invalid_alias_characters 
    ((0..' '.ord).map(&:chr).join('') + "!\"\#$%&'()*,/:;<=>?@[\\]^`{|}~\x7f").chars
  end
  
  
  def self.create_alias(name, user)
    raise BadRequestError, 'alias.missing' unless name
    raise BadRequestError, 'username.missing' unless user
    raise BadRequestError, 'alias.invalid.empty' unless name.size > 0
    raise BadRequestError.new('username.invalid.bad_encoding', :name=>user.encoding.name) unless user.ascii_only?
    raise BadRequestError.new('alias.invalid.bad_encoding', :name=>name.encoding.name) unless name.ascii_only?
    raise BadRequestError.new('alias.invalid.bad_character', :pos=>$`.size) if name =~ Regexp.new(invalid_alias_characters.map{|e| Regexp.escape(e) }.join('|'))
    raise ConflictError, 'alias.exists' if find_alias(name)
    raise BadRequestError, 'username.unknown' unless find_user(user)
    
    Lacuna::Files.modified << paths.aliases
    File.open(paths.aliases, 'a') {|f| f.write "\n#{name}:#{user}" }
    mu = MailUser.new("#{user}@#{Lacuna.domain}")
    Programs.userdb("#{name}@#{Lacuna.domain}", 'set', mu.fields)
    MailAlias.new(name, user)
  end
  
  #def self.remove_user_aliases(user)
  #  raise ArgumentError, "Invalid encoding #{user.encoding.name}" unless user.ascii_only?
  #  m = Regexp.new(":\s*#{user}\s*$")
  #  lines = IO.readlines(paths.aliases).delete_if{|l| l =~ m }
  #  Lacuna::Files.modified << paths.aliases
  #  File.open(paths.aliases+'.tmp', 'w') {|f| lines.each{|line| f.puts line } }
  #  FileUtils.mv(paths.aliases+'.tmp', paths.aliases)
  #end
  
  class MailAlias
    attr_reader :name, :user
    
    def initialize(*args)
      @name, @user = args.map{|e| e.strip}
    end
    
    def remove
      Programs.userdb("#{name}@#{Lacuna.domain}", 'del')
      m = Regexp.new("^#{name}\s*:")
      lines = IO.readlines(Lacuna.paths.aliases).delete_if{|l| l =~ m }
      Lacuna::Files.modified << Lacuna.paths.aliases
      File.open(Lacuna.paths.aliases+'.tmp', 'w') {|f| lines.each{|line| f.puts line } }
      FileUtils.mv(Lacuna.paths.aliases+'.tmp', Lacuna.paths.aliases)
    end
  end
end