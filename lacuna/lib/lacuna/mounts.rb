require 'lacuna/setup'
require 'lacuna/base'
require 'lacuna/fileutils'

module Lacuna
  def self.parse_mounts(data)
    data.split("\n").reject{|e| e =~ /^\s*#/}.map {|e| MountPoint.new(*e.split(/\s+/))}
  end
  
  def self.find_mounts(options)
    options = options.to_hash
    raise ArgumentError, "Missing either spec or file" if options[:spec].nil? && options[:file].nil?
    spec = options[:spec]
    file = options[:file]
    mounts.find_all{|mp| (spec.nil? || mp.spec == spec) && (file.nil? || mp.file == file) }
  end
  
  def self.mounts
    fstab = parse_mounts(IO.read(Lacuna.paths.fstab))
    parse_mounts(Programs.capture(:mount, '-p')).each do |mp|
      fstab.delete(mp)
      fstab << mp
    end
    fstab
  end
  
  class MountPoint
    attr_reader :spec, :file, :vfstype, :mntops, :freq, :passno
    
    def initialize(fs_spec, fs_file, fs_vfstype, fs_mntops, fs_freq, fs_passno=0)
      @spec, @file, @vfstype, @mntops, @freq, @passno = fs_spec, fs_file, fs_vfstype, fs_mntops.split(',').map(&:to_sym), fs_freq.to_i, fs_passno.to_i
    end
    
    def inspect
      "Mount['#{spec}' '#{file}' '#{vfstype}' '#{mntops.join(',')}' #{freq} #{passno}]"
    end
    alias :to_s :inspect
    
    def hash
      spec.hash ^ file.hash
    end
    
    def ==(other)
      other.is_a?(MountPoint) && spec == other.spec && file == other.file
    end
    
    def eql?(other)
      other.is_a?(MountPoint) && spec.eql?(other.spec) && file.eql?(other.file)
    end
  end
end