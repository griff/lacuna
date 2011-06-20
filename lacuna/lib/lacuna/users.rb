require 'lacuna/setup'
require 'lacuna/files'
require 'lacuna/fileutils'
require 'lacuna/aliases'
require 'lacuna/encoding'

module Lacuna
  module Programs
    def pw(cmd, *args)
      options = (Hash === args.last) ? args.pop : {}

      Lacuna::Files.modified << Lacuna.paths[:master_passwd, :passwd, :pwd_db, :spwd_db, :group]

      args << '-u' << options[:uid].to_s if options[:uid]
      args << '-e' << options[:expire].to_s if options[:expire]
      args << '-p' << options[:change].to_s if options[:change]
      args << '-c' << options[:gecos].to_s if options[:gecos]
      args << '-s' << options[:shell].to_s if options[:shell]
      args << '-d' << options[:home_dir].to_s if options[:home_dir]
      args << '-L' << options[:login_class].to_s if options[:login_class]
      args << '-g' << options[:group].to_s if options[:group]
      args << '-m' if options[:create_home] == true
      if options[:password]
        args << '-h' << '0' 
        #puts "pw #{cmd} #{args.join(' ')}"
        sh(options[:password].to_s | pipe(:pw, cmd, *args))
        #IO.popen([program_path(:pw), cmd] + args, 'r+') {|p| p.write(options[:password].to_s) ; p.close_write}
        #$?.exitstatus == 0
      else
        #puts "pw #{cmd} #{args.join(' ')}"
        program(:pw, cmd, *args)
      end
    end

    def userdb(name, cmd, options={})
      _userdb(name, cmd, options) && program(:makeuserdb)
    end

    def _userdb(name, cmd, options={})
      Lacuna::Files.modified << Lacuna.paths[:userdb, :userdb_dat, :userdbshadow_dat]

      if options[:password]
        pwd = options.delete(:password).to_s
        _userdb(name, cmd, options)
        sh(pwd | pipe(:userdbpw) | pipe(:userdb, name, cmd, 'systempw'))
        sh(pwd | pipe(:userdbpw, '-hmac-md5') | pipe(:userdb, name, cmd, 'hmac-md5pw'))
        #IO.popen("#{program_path(:userdbpw)} | #{program_path(:userdb)} #{name} #{cmd} systempw", 'r+') {|p| p.write(pwd) ; p.close_write}
        #IO.popen("#{program_path(:userdbpw)} -hmac-md5 | #{program_path(:userdb)} #{name} #{cmd} hmac-md5pw", 'r+') {|p| p.write(pwd) ; p.close_write}
        #$?.exitstatus == 0
      else
        args = options.map{|k,v| "#{k}=#{v}"}
        program(:userdb, name, cmd, *args)
      end
    end
  end
  
  def self.hostname
    @hostname ||= Programs.capture(:hostname).strip
  end

  def self.host
    @host ||= Programs.capture(:hostname, '-s').strip
  end
  
  def self.domain
    hostname[host.size+1..-1]
  end
  
  def self.users
    Programs.capture(:pw, 'usershow', '-a').split("\n").map {|e| User.new(e.split(':'))}
  end
  
  def self.real_users
    users.find_all{|u| u.real?}
  end
  
  def self.create_user(name, options={})
    name = name.strip if name
    raise ArgumentError, "User name missing" if name.size == 0
    raise ArgumentError, "User name to large" if name.size > 16
    raise ArgumentError, "Invalid encoding #{name.encoding.name}" unless name.ascii_only?
    raise ArgumentError, "Invalid character in name at #{$`.size}" if name =~ /\s|,|:|\+|&|#|%|\$|\^|\(|\)|!|@|~|\*|\?|<|>|=|\||\\|\/|"/
    if options[:gecos]
      gecos = options[:gecos]
      unless gecos.ascii_only?
        gecos = Lacuna::Encoding.encode_word(gecos)
      end
      raise ArgumentError, "Invalid character in gecos at #{$`.size}" if gecos =~ /:|!|@/
      options[:gecos] = gecos
    end
    raise ArgumentError, 'Missing password' if options[:password] && options[:password].size == 0
    if options[:restore]
      require 'lacuna/trash'
      restore = find_user_trash(options[:restore])
      if restore
        options = {
          :group=>restore.group,
          :login_class=>restore.user.login_class,
          :change=>restore.user.change,
          :expire=>restore.user.expire,
          :gecos=>restore.user.gecos,
          :home_dir=>restore.user.home_dir,
          :shell=>restore.user.shell
        }.merge(options)
        grp = find_group(options[:group])
        if grp.nil? && options[:group] == name
          Programs.pw('groupadd', name)
        end

        puts "Restoring #{options[:home_dir]}"
        unless File.exists?(options[:home_dir])
          if File.exists?(restore.prefix + '.tgz')
            Programs.tar('xvf', '-C', File.dirname(restore.prefix), restore.prefix + '.tgz')
          end
          if File.exists?(restore.prefix)
            Programs.mv(restore.prefix, options[:home_dir])
          end
        end
      end
    end
    Programs.pw('useradd', name, options)
    u = User.new(Programs.capture(:pw, 'usershow', name).split(':'))
    Programs.userdb("#{name}@#{domain}" , 'set', :uid=>u.uid, :gid=>u.gid, :home=>u.home_dir, :password=>options[:password])
    
    if restore
      Programs.find(options[:home_dir], '-user', restore.user.uid.to_s, '-exec', 'chown', name, '{}', ';')
      Programs.find(options[:home_dir], '-group', restore.user.gid.to_s, '-exec', 'chgrp', name, '{}', ';')
    end
    u
  end
  
  def self.find_user(name)
    if name.is_a?(Fixnum) || /^\d+$/ =~ name
      name = name.to_i
      users.find{|u| u.uid == name}
    else
      users.find{|u| u.name == name}
    end
  end
  
  class User

    attr_reader :name, :uid, :gid, :login_class, :change, :expire, :gecos, :home_dir, :shell
    attr_writer :password
    
    def initialize(form)
      @name, _, @uid, @gid, @login_class, @change, @expire, @gecos, @home_dir, @shell = form
      @uid, @gid, @change, @expire = [@uid, @gid, @change, @expire].map{|e| e.to_i}
      @gecos = Lacuna::Encoding.decode_word(@gecos) if @gecos =~ /^=\?[^?]+\?(Q|B)\?[^?]*\?=$/i
      @changes = {}
    end
    
    def group
      Lacuna.find_group(gid)
    end
    
    def gecos=(new_name)
      raise ArgumentError, "Invalid character in gecos at #{$`.size}" if new_name =~ /:|!|@/
      @gecos = @changes[:gecos] = new_name if @gecos != new_name
    end

    def shell=(new_name)
      @shell = @changes[:shell] = new_name if @shell != new_name
    end
    
    def password=(new_one)
      @changes[:password] = new_one
    end
    
    def commit_changes
      gecos = @changes[:gecos]
      @changes[:gecos] = Lacuna::Encoding.encode_word(gecos) unless gecos.nil? || gecos.ascii_only?
      
      if @changes[:password]
        Programs.userdb("#{name}@#{Lacuna.domain}", 'set', :password=>@changes[:password])
        mail_aliases.each {|l| Programs.userdb("#{l.name}@#{Lacuna.domain}", 'set', :password=>@changes[:password]) }
      end
      Programs.pw 'usermod', name, @changes
    end
    
    def usage
      return 0 unless File.exists?(home_dir)
      file = File.join(home_dir, '.usage')
      begin
        IO.read(file).split[0]
      rescue Errno::ENOENT => e
        warn "Usage file #{file} not found"
        0
        #calculate_usage
      end
    end
    
    def calculate_usage
      usage = Programs.capture(:du,  '-sm',  home_dir)
      File.open(File.join(home_dir, '.usage'), 'w') {|f| f.write(usage)}
      usage.split[0]
    end
    
    def mail_aliases
      Lacuna.find_user_aliases(name)
    end
    
    def to_master_s
      gecos = self.gecos
      gecos = Lacuna::Encoding.encode_word(gecos) unless gecos.ascii_only?
      "#{name}:*:#{uid}:#{gid}:#{login_class}:#{change}:#{expire}:#{gecos}:#{home_dir}:#{shell}"
    end
    
    def real?
      uid >= 1000 && uid < 32000
    end
    
    def remove
      if real? 
        if File.exist?(home_dir)
          File.open(File.join(home_dir, '.deleted'), File::RDWR|File::CREAT, 0600) do |f|
            f.flock(File::LOCK_EX)
            if File.exist?(home_dir)
              trash = trashbase = paths.home_trash/name
              while File.exist?(trash) || File.exist?(trash+'.tgz') || File.exist?(trash+'.deleted')
                idx = (idx || 0) + 1
                trash = "#{trashbase}-#{idx}"
              end
          
              time = Time.now.to_i
              autodel = time + 30 * 24 * 60 * 60 # 30 days
              group = Lacuna.find_group(gid)
              f.puts("#{self.to_master_s}:#{group.name}:#{time}:#{autodel}")
              #File.open(File.join(home_dir, '.user'), "w") {|f2| f2.puts(self.to_master_s)}

              Programs.mv(home_dir, trash)
            end
          end
        end
        Lacuna.remove_user_aliases(name)
        Programs.userdb("#{name}@#{Lacuna.domain}", 'del') &&
          Programs.pw('userdel', name)
      end
    end
  end
  
  
  def self.groups
    Programs.capture(:pw, 'groupshow', '-a').split("\n").map{|g| Group.new(g.split(':'))}
  end
  
  def self.find_group(name)
    if name.is_a?(Fixnum) || /^\d+$/ =~ name
      name = name.to_i
      groups.find{|u| u.gid == name}
    else
      groups.find{|u| u.name == name}
    end
  end
  
  class Group
    attr_reader :name, :gid, :users
    
    def initialize(form)
      @name, _, @gid, @users = form[0], form[1], form[2].to_i, (form[3] ? form[3].split(',') : [])
    end
    
    def to_s
      "#{name}:*:#{gid}:#{users.join(',')}"
    end
  end
end