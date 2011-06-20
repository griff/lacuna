require 'lacuna/fileutils'

module Lacuna
  class Files
    def self.modified
      @modified ||= []
    end
    
    def self.save
      @modified, files = [], modified
      Files.new(files.flatten).save
    end
    
    attr_reader :files

    def initialize(files)
      @files = files
    end
    
    def save
      cfg, etc, local_etc = Lacuna.paths(:cfg, :etc, :local_etc)
      Programs.mount cfg do
        files.uniq.each do |f|
          src, dst, shared = if f.start_with?(etc)
            [etc, cfg, f[4..-1]]
          elsif f.start_with?(local_etc)
            [local_etc, cfg/:local, f[14..-1]]
          end
          next unless src && File.exist?(f)

          Programs.copy_path(src, dst, shared)
        end
      end
    end
  end
end