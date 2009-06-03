BSD::Config.defaults do |c|
  c.paths do |p|
    p[:prefix] = '/'
    p[:etc] = p[:prefix] / 'etc'
    p[:lib] = p[:prefix] / 'lib'
    p[:sbin] = p[:prefix] / 'sbin'
    p[:var_run] = p[:prefix] / 'var/run'
    p[:var_log] = p[:prefix] / 'var/log'
    p[:var_db] = p[:prefix] / 'var/db'
  end
  c.product do |p|
    p[:name] = 'RubyBSD'
    p[:copyright] = '2009'
  end
  c.programs do |p|
    p[:ifconfig] = c.paths[:sbin] / 'ifconfig'
  end
end