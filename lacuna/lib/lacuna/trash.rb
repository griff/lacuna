require 'lacuna/setup'
require 'lacuna/users'
require 'date'

module Lacuna
  def self.user_trash
    trash = Dir["#{paths.home_trash}/*"].map do |d|
      if File.directory?(d)
        File.basename(d)
      else
        File.basename(d, File.extname(d))
      end
    end
    trash.uniq.map{|f| UserTrash.new(paths.home_trash/f)}.sort
  end
  
  def self.find_user_trash(folder)
    user_trash.find{|t| t.folder == folder}
  end

  class UserTrash
    attr_reader :prefix, :folder, :user, :group, :time, :autodelete, :aliases

    def initialize(prefix)
      @prefix = prefix
      deleted_file = prefix + '.deleted'
      deleted_file = prefix/'.deleted' unless File.exist?(deleted_file)
      @folder = File.basename(prefix)
      @aliases = IO.read(deleted_file).split("\n").map(&:strip)
      info = @aliases.shift.split(':')
      @user, @group, @time, @autodelete = User.new(info[0..9]), info[10], info[11], info[12]
      @time, @autodelete = Time.at(@time.to_i), @autodelete.to_i
      @time = Date.new(@time.year, @time.month, @time.day)
    end
    
    def name
      user.name
    end
    
    def days_to_autodelete
      timetil = autodelete - Time.now.to_i
      timetil > 0 ? timetil.div(60*60*24) : 0
    end
    
    def <=>(o)
      r = self.time <=> o.time
      r != 0 ? r : self.folder <=> o.folder
    end
    
    def remove
      FileUtils.rm_rf(prefix, :secure=>true)
      FileUtils.rm_rf(prefix+'.deleted', :secure=>true)
      FileUtils.rm_rf(prefix+'.tgz', :secure=>true)
    end
  end
end