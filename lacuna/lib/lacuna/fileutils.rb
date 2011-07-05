require 'fileutils'
require 'lacuna/configuration'

class PipedCommand
  attr_reader :left, :right
  def initialize(left, right)
    @left, @right = left, right
  end
  
  def show_command(cutof=0)
    ret = left.cmd.join(' ') + " | " + right.cmd.join(' ')
    ret = ret[0,cutof-3] + "..." if cutof > 4 && ret.size > cutof
    ret
  end

  def success?
    left.success? && right.success?
  end
  
  def completed?
    left.completed? && (!left.success? || right.completed?)
  end
  
  def run
    unless completed?
      right.input = left.result
      right.run
    end
  end
  
  def result
    run
    right.result
  end
  
  def status
    run
    left.success? ? right.status : left.status
  end
  
  def to_s
    result.to_s
  end

  def |(other)
    PipedCommand.new(self, other)
  end
end

class CommandPipe
  attr_reader :cmd, :input
  
  def initialize(*cmd, &block)
    @cmd = cmd
    @status = @input = @result = nil
    @default_block = lambda { |ok, status, output|
      ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command(45)}]"
      output
    }
    block = @default_block unless block_given?
    @block = block
  end
  
  def show_command(cutof=0)
    ret = cmd.join(" ")
    ret = ret[0,cutof-3] + "..." if cutof > 4 && ret.size > cutof
    ret
  end
  
  def completed?
    !@status.nil?
  end
  
  def success?
    status.success?
  end
  
  def status
    run
    @status
  end
  
  def result
    run
    @result
  end
  
  def input=(input)
    raise "Command [#{show_command}] already completed" if completed?
    @input = input
  end
  
  def run
    unless completed?
      mode = input.nil? ? "r" : "r+"
      output = IO.popen(cmd, mode) do |io|
        unless input.nil?
          io.write(input.to_s)
          io.close_write
        end
        io.read
      end
      @status = $?
      if @block.arity == 4 || @block.arity < 0
        @result = @block.call(@status.success?, @status, output, @default_block)
      else
        @result = block.call(@status.success?, @status, output)
      end
    end
  end
  
  def to_s
    result.to_s
  end
  
  def |(other)
    PipedCommand.new(self, other)
  end
end

class String
  def |(other)
    if other.is_a?(CommandPipe)
      other.input = self
      other
    else
      super
    end
  end
end

# ###########################################################################
# This a FileUtils extension that defines several additional commands to be
# added to the FileUtils utility functions.
#
module FileUtils
  
  class SystemExitError < StandardError
    ERRORS = {
      :usage => 64,
      :dataerr => 65,
      :noinput => 66,
      :nouser => 67,
      :nohost => 68,
      :unavailable => 69,
      :software => 70,
      :oserr => 71,
      :osfile => 72,
      :cantcreate => 73,
      :ioerr => 74,
      :tempfail => 75,
      :protocol => 76,
      :noperm => 77,
      :config => 78
    }
    CONVERT = Hash.new
    ERRORS.each do |key, value|
      const_set("EX_#{key.upcase}", value)
      CONVERT[value] = key
    end
    
    def initialize(err)
      super("System exit code #{CONVERT[err]}")
    end
  end
  
  OPT_TABLE['sh']  = %w(noop verbose)
  OPT_TABLE['capture_sh']  = %w(noop verbose)

  # Run the system command +cmd+. If multiple arguments are given the command
  # is not run with the shell (same semantics as Kernel::exec and
  # Kernel::system).
  #
  # Example:
  #   sh %{ls -ltr}
  #
  #   sh 'ls', 'file with spaces'
  #
  #   # check exit status after command runs
  #   sh %{grep pattern file} do |ok, res|
  #     if ! ok
  #       puts "pattern not found (status = #{res.exitstatus})"
  #     end
  #   end
  #
  def sh(*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}
    first = cmd.first
    unless block_given?
      if first.respond_to? :show_command
        show_comman = first.show_command(45)
      else
        show_command = cmd.join(" ")
        show_command = show_command[0,42] + "..." if show_command.size > 45
      end
      block = lambda { |ok, status|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}]"
      }
    end
    fu_check_options options, OPT_TABLE['sh']
    fu_output_message(first.respond_to?(:show_command) ? first.show_command : cmd.join(" ")) if options[:verbose]
    unless options[:noop]
      if first.respond_to? :run
        first.run
        block.call(first.success?, first.status)
      else
        res = system(*cmd)
        block.call(res, $?)
      end
    end
  end
  module_function :sh
  
  def capture_sh(*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}
    first = cmd.first
    unless block_given?
      if first.respond_to? :show_command
        show_comman = first.show_command(45)
      else
        show_command = cmd.join(" ")
        show_command = show_command[0,42] + "..." if show_command.size > 45
      end
      block = lambda { |ok, status, output|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}]"
        output
      }
    end
    fu_check_options options, OPT_TABLE['capture_sh']
    fu_output_message(first.respond_to?(:show_command) ? first.show_command : cmd.join(" ")) if options[:verbose]
    unless options[:noop]
      if first.respond_to? :run
        first.run
        block.call(first.success?, first.status, first.result)
      else
        output = IO.popen(cmd) {|io| io.read }
        block.call($?.success?, $?, output)
      end
    end
  end
  module_function :capture_sh
  
  def pipe(*cmd, &block)
    CommandPipe.new(*cmd, &block)
  end
  module_function :pipe

  def copy_metadata(src, path)
    st = File.stat(src)
    File.utime st.atime, st.mtime, path
    begin
      File.chown st.uid, st.gid, path
    rescue Errno::EPERM
      # clear setuid/setgid
      File.chmod st.mode & 01777, path
    else
      File.chmod st.mode, path
    end
  end
  module_function :copy_metadata
  
  def copy_path(src, dst, shared)
    unless File.exist?(dst)
      mkdir(dst)
      copy_metadata(src, dst)
    end
    
    processed = []
    shared.split('/')[0..-2].each do |e|
      d = File.join(dst, processed, e)
      unless File.exist?(File.join(dst, processed, e))
        mkdir(d)
        copy_metadata(File.join(src, processed, e), d)
      end
      processed << e
    end
    
    cp(File.join(src, shared), File.join(dst, shared), :preserve=>true)
  end
  module_function :copy_path  
end

module Lacuna
  module Programs
    include FileUtils::Verbose
    
    def program_path(sym)
      path = Lacuna.programs[sym].to_s
      raise ArgumentError, "Missing path for program #{sym}" if path.size == 0
      path
    end
    
    def program(sym, *args)
      sh(program_path(sym), *args) do |ok, status|
        ok or raise SystemExitError, status.exitstatus
      end
    end
    
    def capture(sym, *args)
      enc_group = Lacuna.configuration.capture_encodings
      enc = (enc_group[sym] | enc_group.default).to_s
      
      capture_sh(program_path(sym), *args).force_encoding(enc)
    end
    
    def pipe(sym, *args)
      enc_group = Lacuna.configuration.capture_encodings
      enc = (enc_group[sym] | enc_group.default).to_s
  
      FileUtils.pipe(program_path(sym), *args) do |ok, status, output, default|
        default.call(ok, status, output && output.force_encoding(enc))
      end
    end
    
    def mount(*args)
      if program(:mount, *args)
        begin
          yield
        ensure
          program(:umount, args[0])
        end
      end
    end
    
    def method_missing(*args)
      program(*args)
    end
    
    extend Programs
  end
end