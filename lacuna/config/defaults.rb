Lacuna::Configuration.defaults do |c|
  c.paths do |p|
    p.prefix = ''
    p.bin = p.prefix/:bin
    p.sbin = p.prefix/:sbin
    p.etc = p.prefix/:etc
    p.usr = p.prefix/:usr
    p.usr_sbin = p.usr/:sbin
    p.usr_bin = p.usr/:bin
    p.usr_local = p.usr/:local
    p.local_etc = p.usr_local / :etc
    p.local_lib = p.usr_local / :lib
    p.local_bin = p.usr_local / :bin
    p.local_sbin = p.usr_local / :sbin
    p.var = p.prefix / :var
    p.var_run = p.var / :run
    p.var_log = p.var / :log
    p.var_db = p.var / :db
    p.aliases = p.etc/:aliases
    p.fstab = p.etc/:fstab

    p.socket = p.var_run/'lacuna.socket'
    p.tokens = p.var_run/'lacuna.tokens'
    p.authdaemond_socket = p.var_run/:authdaemond/:socket

    p.cfg = p.prefix/:cfg

    p.exim_msglog = p.var/:spool/:exim/:msglog
    
    p.master_passwd = p.etc/'master.passwd'
    p.passwd = p.etc/:passwd
    p.pwd_db = p.etc/'pwd.db'
    p.spwd_db = p.etc/'spwd.db'
    p.group = p.etc/:group
    
    p.userdb = p.local_etc/:userdb
    p.userdb_dat = p.local_etc/'userdb.dat'
    p.userdbshadow_dat = p.local_etc/'userdbshadow.dat'
    p.home_base = p.var/:home
    p.home_trash = p.var/'home.trash'
  end
  c.programs do |p|
    pa = c.paths
    p.ifconfig = pa.usr_sbin/:ifconfig
    p.mount = pa.sbin/:mount
    p.umount = pa.sbin/:umount
    p.pw = pa.usr_sbin/:pw
    p.userdb = pa.local_sbin/:userdb
    p.makeuserdb = pa.local_sbin/:makeuserdb
    p.userdbpw = pa.local_sbin/:userdbpw
    p.exim = pa.local_sbin/:exim
    p.maildirmake = pa.local_bin/:maildirmake
    p.find = pa.usr_bin/:find
    p.tar = pa.usr_bin/:tar
    p.du = pa.usr_bin/:du
    p.hostname = pa.bin/:hostname
  end
  c.product do |p|
    p.name = 'Lacuna'
    p.copyright = Time.now.year
  end
  c.capture_encodings do |p|
    p.default = 'ASCII-8BIT'
  end
  c.encodings do |p|
    p.gecos = 'UTF-8'
  end
end