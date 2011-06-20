Lacuna::Config.defaults do |c|
  c.paths do |p|
    p.prefix = '/'
    p.code = p.prefix / :usr / :local
    p.etc = p.code / :etc
    p.lib = p.code / :lib
    p.sbin = p.code / :sbin
    p.var = p.prefix / :var
    p.var_run = p.var / :run
    p.var_log = p.var / :log
    p.var_db = p.var / :db
    p.home '/var/lacuna', '/usr/lacuna'
  end
  c.product do |p|
    p.name = 'Lacuna'
    p.copyright = '2011'
  end
  c.programs do |p|
    p.ifconfig = c.paths.sbin / :ifconfig
  end
end