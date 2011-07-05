require 'openssl'
require 'base64'
require 'socket'

module Lacuna
  # Generate a random key of up to +size+ bytes. The value returned is Base64 encoded with non-word
  # characters removed.
  def self.generate_key(size=32)
    Base64.encode64(OpenSSL::Random.random_bytes(size)).gsub(/\W/, '')
  end

  def self.login(user, password)
    UNIXSocket.open(paths.authdaemond_socket) do |socket|
      line = "lacuna\nlogin\n#{user}\n#{password}\n"
      line = "#{line.size}\n#{line}"
      socket.write("AUTH #{line}")
      data = socket.read
      return data.size > 0 && data != "FAIL\n"
    end
  end

  def self.make_token(user, timeout=3600)
    ts = Time.now.to_i + timeout
    File.open(paths.tokens, File::RDWR|File::CREAT, 0600) do |f|
      f.flock(File::LOCK_EX)
      tokens = f.readlines.map{|l| l.split(':')[0]}
      token = generate_key while token.nil? || tokens.include?(token)
      token = Token.new(token, user, ts)
      f.puts token.to_s
      f.flush
      token
    end
  end

  def self.tokens
    File.open(paths.tokens, File::RDWR|File::CREAT, 0600) do |f|
      f.flock(File::LOCK_SH)
      tokens = f.readlines.map{|l| Token.new(*l.split(':'))}
      valid_tokens = tokens.find_all{|t| t.valid?}
      if valid_tokens.size != tokens.size
        f.flock(File::LOCK_EX)
        f.truncate(0)
        f.rewind
        valid_tokens.each{|t| f.puts t.to_s }
        f.flush
      end
      valid_tokens
    end
  end

  def self.find_token(token)
    tokens.find{|t| t.token == token}
  end

  class Token
    attr_reader :token, :username, :timestamp
    alias :access_token :token

    def initialize(token, username, timestamp)
      @token, @username, @timestamp, @timeout = token, username, timestamp.to_i
    end

    def valid?
      timestamp == 0 || timestamp > Time.now.to_i
    end

    def expires_in
      timestamp - Time.now.to_i
    end

    def scope
      'all'
    end
    
    def scopes
      ['all'].to_set
    end

    def [](name)
      send(name)
    end

    def to_s
      "#{token}:#{username}:#{timestamp}"
    end
  end
end