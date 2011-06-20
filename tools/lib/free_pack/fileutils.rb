require 'fileutils'

# ###########################################################################
# This a FileUtils extension that defines several additional commands to be
# added to the FileUtils utility functions.
#
module FileUtils
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
    unless block_given?
      show_command = cmd.join(" ")
      show_command = show_command[0,42] + "..."
      # TODO code application logic heref show_command.length > 45
      block = lambda { |ok, status|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}]"
      }
    end
    fu_check_options options, OPT_TABLE['sh']
    fu_output_message cmd.join(" ") if options[:verbose]
    unless options[:noop]
      res = system(*cmd)
      block.call(res, $?)
    end
  end
  
  def capture_sh(*cmd, &block)
    options = (Hash === cmd.last) ? cmd.pop : {}
    unless block_given?
      show_command = cmd.join(" ")
      show_command = show_command[0,42] + "..."
      # TODO code application logic heref show_command.length > 45
      block = lambda { |ok, status, output|
        ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}]"
        output
      }
    end
    fu_check_options options, OPT_TABLE['capture']
    fu_output_message cmd.join(" ") if options[:verbose]
    unless options[:noop]
      output = IO.popen(cmd) {|io| io.read }
      block.call($?.success?, $?, output)
    end
  end
end