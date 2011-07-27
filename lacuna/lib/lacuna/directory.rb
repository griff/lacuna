module Lacuna
  def self.directory
    
  end
  
  class VirtualPath
    def initialize(path)
      path = path.to_str if path.respond_to? :to_str
      @path = path.dup

      if /\0/ =~ @path
        raise ArgumentError, "virtual path contains \\0: #{@path.inspect}"
      end

      self.taint if @path.tainted?
    end

    def freeze() super; @path.freeze; self end
    def taint() super; @path.taint; self end
    def untaint() super; @path.untaint; self end

    #
    # Compare this virtual path with +other+.  The comparison is string-based.
    # Be aware that two different paths (<tt>foo.txt</tt> and <tt>./foo.txt</tt>)
    # can refer to the same file.
    #
    def ==(other)
      return false unless VirtualPath === other
      other.to_s == @path
    end
    alias === ==
    alias eql? ==

    # Provides for comparing virtual paths, case-sensitively.
    def <=>(other)
      return nil unless VirtualPath === other
      @path.tr('/', "\0") <=> other.to_s.tr('/', "\0")
    end

    def hash # :nodoc:
      @path.hash
    end

    # Return the path as a String.
    def to_s
      @path.dup
    end

    def inspect # :nodoc:
      "#<#{self.class}:#{@path}>"
    end

    # Return a virtual path which is substituted by String#sub.
    def sub(pattern, *rest, &block)
      if block
        path = @path.sub(pattern, *rest) {|*args|
          begin
            old = Thread.current[:virtualpath_sub_matchdata]
            Thread.current[:virtualpath_sub_matchdata] = $~
            eval("$~ = Thread.current[:virtualpath_sub_matchdata]", block.binding)
          ensure
            Thread.current[:virtualpath_sub_matchdata] = old
          end
          yield(*args)
        }
      else
        path = @path.sub(pattern, *rest)
      end
      self.class.new(path)
    end

    SEPARATOR_LIST = '\/'
    SEPARATOR_PAT = %r{/}
    
    # Return a virtual path which the extension of the basename is substituted by
    # <i>repl</i>.
    #
    # If self has no extension part, <i>repl</i> is appended.
    def sub_ext(repl)
      ext = File.extname(@path)
      self.class.new(@path.chomp(ext) + repl)
    end
    
    # chop_basename(path) -> [pre-basename, basename] or nil
    def chop_basename(path)
      base = File.basename(path)
      if /\A#{SEPARATOR_PAT}?\z/o =~ base
        return nil
      else
        return path[0, path.rindex(base)], base
      end
    end
    private :chop_basename

    # split_names(path) -> prefix, [name, ...]
    def split_names(path)
      names = []
      while r = chop_basename(path)
        path, basename = r
        names.unshift basename
      end
      return path, names
    end
    private :split_names

    def prepend_prefix(prefix, relpath)
      if relpath.empty?
        File.dirname(prefix)
      elsif /#{SEPARATOR_PAT}/o =~ prefix
        prefix = File.dirname(prefix)
        prefix = File.join(prefix, "") if File.basename(prefix + 'a') != 'a'
        prefix + relpath
      else
        prefix + relpath
      end
    end
    private :prepend_prefix

    #
    # Clean the path simply by resolving and removing excess "." and ".." entries.
    # Nothing more, nothing less.
    #
    def cleanpath
      path = @path
      names = []
      pre = path
      while r = chop_basename(pre)
        pre, base = r
        case base
        when '.'
        when '..'
          names.unshift base
        else
          if names[0] == '..'
            names.shift
          else
            names.unshift base
          end
        end
      end
      if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
        names.shift while names[0] == '..'
      end
      self.class.new(prepend_prefix(pre, File.join(*names)))
    end

    # has_trailing_separator?(path) -> bool
    def has_trailing_separator?(path)
      if r = chop_basename(path)
        pre, basename = r
        pre.length + basename.length < path.length
      else
        false
      end
    end
    private :has_trailing_separator?

    # add_trailing_separator(path) -> path
    def add_trailing_separator(path)
      if File.basename(path + 'a') == 'a'
        path
      else
        File.join(path, "") # xxx: Is File.join is appropriate to add separator?
      end
    end
    private :add_trailing_separator

    def del_trailing_separator(path)
      if r = chop_basename(path)
        pre, basename = r
        pre + basename
      elsif /#{SEPARATOR_PAT}+\z/o =~ path
        $` + File.dirname(path)[/#{SEPARATOR_PAT}*\z/o]
      else
        path
      end
    end
    private :del_trailing_separator

    # #parent returns the parent directory.
    #
    # This is same as <tt>self + '..'</tt>.
    def parent
      self + '..'
    end

    #
    # #root? is a predicate for root directories.  I.e. it returns +true+ if the
    # virtual path consists of consecutive slashes.
    #
    # It doesn't access actual filesystem.  So it may return +false+ for some
    # virtual paths which points to roots such as <tt>/usr/..</tt>.
    #
    def root?
      !!(chop_basename(@path) == nil && /#{SEPARATOR_PAT}/o =~ @path)
    end

    # Predicate method for testing whether a path is absolute.
    # It returns +true+ if the virtual path begins with a slash.
    def absolute?
      !relative?
    end

    # The opposite of #absolute?
    def relative?
      path = @path
      while r = chop_basename(path)
        path, basename = r
      end
      path == ''
    end

    #
    # Iterates over each component of the path.
    #
    #   VirtualPath.new("/usr/bin/ruby").each_filename {|filename| ... }
    #     # yields "usr", "bin", and "ruby".
    #
    def each_filename # :yield: filename
      return to_enum(__method__) unless block_given?
      prefix, names = split_names(@path)
      names.each {|filename| yield filename }
      nil
    end

    # Iterates over and yields a new VirtualPath object
    # for each element in the given path in descending order.
    #
    #  VirtualPath.new('/path/to/some/file.rb').descend {|v| p v}
    #     #<VirtualPath:/>
    #     #<VirtualPath:/path>
    #     #<VirtualPath:/path/to>
    #     #<VirtualPath:/path/to/some>
    #     #<VirtualPath:/path/to/some/file.rb>
    #
    #  VirtualPath.new('path/to/some/file.rb').descend {|v| p v}
    #     #<VirtualPath:path>
    #     #<VirtualPath:path/to>
    #     #<VirtualPath:path/to/some>
    #     #<VirtualPath:path/to/some/file.rb>
    #
    # It doesn't access actual filesystem.
    #
    # This method is available since 1.8.5.
    #
    def descend
      vs = []
      ascend {|v| vs << v }
      vs.reverse_each {|v| yield v }
      nil
    end

    # Iterates over and yields a new VirtualPath object
    # for each element in the given path in ascending order.
    #
    #  VirtualPath.new('/path/to/some/file.rb').ascend {|v| p v}
    #     #<VirtualPath:/path/to/some/file.rb>
    #     #<VirtualPath:/path/to/some>
    #     #<VirtualPath:/path/to>
    #     #<VirtualPath:/path>
    #     #<VirtualPath:/>
    #
    #  VirtualPath.new('path/to/some/file.rb').ascend {|v| p v}
    #     #<VirtualPath:path/to/some/file.rb>
    #     #<VirtualPath:path/to/some>
    #     #<VirtualPath:path/to>
    #     #<VirtualPath:path>
    #
    # It doesn't access actual filesystem.
    #
    # This method is available since 1.8.5.
    #
    def ascend
      path = @path
      yield self
      while r = chop_basename(path)
        path, name = r
        break if path.empty?
        yield self.class.new(del_trailing_separator(path))
      end
    end

    #
    # VirtualPath#+ appends a virtual path fragment to this one to produce a new VirtualPath
    # object.
    #
    #   p1 = VirtualPath.new("/usr")      # VirtualPath:/usr
    #   p2 = p1 + "bin/ruby"           # VirtualPath:/usr/bin/ruby
    #   p3 = p1 + "/etc/passwd"        # VirtualPath:/etc/passwd
    #
    # This method doesn't access the file system; it is pure string manipulation.
    #
    def +(other)
      other = VirtualPath.new(other) unless VirtualPath === other
      VirtualPath.new(plus(@path, other.to_s))
    end

    def plus(path1, path2) # -> path
      prefix2 = path2
      index_list2 = []
      basename_list2 = []
      while r2 = chop_basename(prefix2)
        prefix2, basename2 = r2
        index_list2.unshift prefix2.length
        basename_list2.unshift basename2
      end
      return path2 if prefix2 != ''
      prefix1 = path1
      while true
        while !basename_list2.empty? && basename_list2.first == '.'
          index_list2.shift
          basename_list2.shift
        end
        break unless r1 = chop_basename(prefix1)
        prefix1, basename1 = r1
        next if basename1 == '.'
        if basename1 == '..' || basename_list2.empty? || basename_list2.first != '..'
          prefix1 = prefix1 + basename1
          break
        end
        index_list2.shift
        basename_list2.shift
      end
      r1 = chop_basename(prefix1)
      if !r1 && /#{SEPARATOR_PAT}/o =~ File.basename(prefix1)
        while !basename_list2.empty? && basename_list2.first == '..'
          index_list2.shift
          basename_list2.shift
        end
      end
      if !basename_list2.empty?
        suffix2 = path2[index_list2.first..-1]
        r1 ? File.join(prefix1, suffix2) : prefix1 + suffix2
      else
        r1 ? prefix1 : File.dirname(prefix1)
      end
    end
    private :plus

    #
    # VirtualPath#join joins virtual paths.
    #
    # <tt>path0.join(path1, ..., pathN)</tt> is the same as
    # <tt>path0 + path1 + ... + pathN</tt>.
    #
    def join(*args)
      args.unshift self
      result = args.pop
      result = VirtualPath.new(result) unless VirtualPath === result
      return result if result.absolute?
      args.reverse_each {|arg|
        arg = VirtualPath.new(arg) unless VirtualPath === arg
        result = arg + result
        return result if result.absolute?
      }
      result
    end

    # Iterates over the children of the directory
    # (files and subdirectories, not recursive).
    # It yields VirtualPath object for each child.
    # By default, the yielded virtual path will have enough information to access the files.
    # If you set +with_directory+ to +false+, then the returned virtual paths will contain the filename only.
    #
    #   VirtualPath("/usr/local").each_child {|f| p f }
    #   #=> #<VirtualPath:/usr/local/share>
    #   #   #<VirtualPath:/usr/local/bin>
    #   #   #<VirtualPath:/usr/local/games>
    #   #   #<VirtualPath:/usr/local/lib>
    #   #   #<VirtualPath:/usr/local/include>
    #   #   #<VirtualPath:/usr/local/sbin>
    #   #   #<VirtualPath:/usr/local/src>
    #   #   #<VirtualPath:/usr/local/man>
    #
    #   VirtualPath("/usr/local").each_child(false) {|f| p f }
    #   #=> #<VirtualPath:share>
    #   #   #<VirtualPath:bin>
    #   #   #<VirtualPath:games>
    #   #   #<VirtualPath:lib>
    #   #   #<VirtualPath:include>
    #   #   #<VirtualPath:sbin>
    #   #   #<VirtualPath:src>
    #   #   #<VirtualPath:man>
    #
    def each_child(&b)
      children.each(&b)
    end

    #
    # #relative_path_from returns a relative path from the argument to the
    # receiver.  If +self+ is absolute, the argument must be absolute too.  If
    # +self+ is relative, the argument must be relative too.
    #
    # #relative_path_from doesn't access the filesystem.  It assumes no symlinks.
    #
    # ArgumentError is raised when it cannot find a relative path.
    #
    # This method has existed since 1.8.1.
    #
    def relative_path_from(base_directory)
      dest_directory = self.cleanpath.to_s
      base_directory = base_directory.cleanpath.to_s
      dest_prefix = dest_directory
      dest_names = []
      while r = chop_basename(dest_prefix)
        dest_prefix, basename = r
        dest_names.unshift basename if basename != '.'
      end
      base_prefix = base_directory
      base_names = []
      while r = chop_basename(base_prefix)
        base_prefix, basename = r
        base_names.unshift basename if basename != '.'
      end
      unless SAME_PATHS[dest_prefix, base_prefix]
        raise ArgumentError, "different prefix: #{dest_prefix.inspect} and #{base_directory.inspect}"
      end
      while !dest_names.empty? &&
            !base_names.empty? &&
            SAME_PATHS[dest_names.first, base_names.first]
        dest_names.shift
        base_names.shift
      end
      if base_names.include? '..'
        raise ArgumentError, "base_directory has ..: #{base_directory.inspect}"
      end
      base_names.fill('..')
      relpath_names = base_names + dest_names
      if relpath_names.empty?
        VirtualPath.new('.')
      else
        VirtualPath.new(File.join(*relpath_names))
      end
    end
    
    
    # See <tt>File.fnmatch</tt>.  Return +true+ if the receiver matches the given
    # pattern.
    def fnmatch(pattern, *args) File.fnmatch(pattern, @path, *args) end

    # See <tt>File.fnmatch?</tt> (same as #fnmatch).
    def fnmatch?(pattern, *args) File.fnmatch?(pattern, @path, *args) end

    # See <tt>File.basename</tt>.  Returns the last component of the path.
    def basename(*args) self.class.new(File.basename(@path, *args)) end

    # See <tt>File.dirname</tt>.  Returns all but the last component of the path.
    def dirname() self.class.new(File.dirname(@path)) end

    # See <tt>File.extname</tt>.  Returns the file's extension.
    def extname() File.extname(@path) end

    # See <tt>File.split</tt>.  Returns the #dirname and the #basename in an
    # Array.
    def split() File.split(@path).map {|f| self.class.new(f) } end

  end
  
  class Users < Directory
    map 'all' do 
      list Lacuna.users
      create Lacuna.create_user
      read
    end
    
    map 'real' do
      list Lacuna.real_users
      create Lacuna.create_user
      read
      update
      delete 
    end
    
    map 'trash' do
      list Lacuna.trash
      create
      read
      update
      delete
    end
  end
  
  class Directory
    def each
    end
  end

  class Container
    
  end
  
  class Entry
    def properties
    end
  end
end