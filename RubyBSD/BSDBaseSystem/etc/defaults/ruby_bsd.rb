BSD::Config.defaults do |c|
  c.node :paths do |p|
    prefix = '/'
    p[:prefix] = prefix
    p[:etc] = prefix / 'etc'
    p[:lib] = prefix / 'lib'
    p[:var_run] = prefix / 'var/run'
    p[:var_log] = prefix / 'var/log'
    p[:var_db] = prefix / 'var/db'
  end
  c.node :product do |p|
    p[:name] = 'PLPL'
    p[:copyright] = '2009'
  end
  c.node :programs do |p|
    p[:ifconfig] = '/sbin/ifconfig'
  end
end