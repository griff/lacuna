def clean_users
  `pw usershow -a`.force_encoding("ASCII-8BIT").split("\n").each do |u|
    data = u.split(':') 
    uid = data[2].to_i
    name = data[0]
    next if uid <1000 || uid > 32000 || name == 'admin'
    
    FileUtils.sh 'pw', 'userdel', uid.to_s
  end
  `userdb -show`.force_encoding("ASCII-8BIT").split("\n").each do |u|
    next if u == "admin@#{Lacuna.domain}"
    FileUtils.sh('userdb', u, 'del')
  end
  Dir["#{Lacuna.paths.home_base}/*"].each do |f|
    next if File.basename(f) == 'admin'
    FileUtils.rm_rf(f)
  end
  Dir["#{Lacuna.paths.home_trash}/*"].each do |f|
    FileUtils.rm_rf(f)
  end
end

def backup_aliases
  p_aliases = Lacuna.configuration.paths.aliases
  FileUtils.copy_file(p_aliases, "#{p_aliases}.backup", true)
  File.open(p_aliases, 'w') {|f| f.write '# Empty for test'}
end

def restore_aliases
  p_aliases = Lacuna.configuration.paths.aliases
  FileUtils.mv("#{p_aliases}.backup", p_aliases)
end
