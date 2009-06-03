module BSD
  module Network
    class << self
      def interfaces(flush=false)
        @network_interfaces = nil if flush
        @network_interfaces ||= run(:ifconfig, '-l').split.map{|device| Interface.new(device)}
      end
      
      def ll(mode=:active, vfaces=nil)
        unless vfaces
          vfaces = ['bridge',
            'ppp',
            'sl',
            'gif',
            'gre',
            'faith',
            'lo',
            'ng',
            'vlan',
            'pflog',
            'pfsync',
            'enc',
            'tun',
            'carp',
            'lagg',
            'plip']
        end
      end

    end

    class Interface
      def self.is_macaddr(addr)
        addr = addr.to_s.strip.split(':')
        return addr.length == 6 && addr.all? {|e| e=~ /^[0-9a-fA-F]{2}$/}
      end
      
      attr_reader :device, :id

      def initialize(id, device)
        @id = id
        @device = device
      end

      def _info
        run :ifconfig,  device
      end

      def mac
        if _info =~ /ether\s+([0-9a-fA-F:]*)/
          mac = $1
          return mac if is_macaddr(mac)
        end
        return "ff:ff:ff:ff:ff:ff"
      end
      
      def exists?
        run_silent :ifconfig, '-n', device
      end

      def create
        execute :ifconfig, device, 'create'
      end

      def destroy
        execute :ifconfig, device, 'destroy'
      end

      def up
        execute :ifconfig, device, 'up'
      end

      def down
        execute :ifconfig, device, 'down'
      end
      
      def restart
        stop
        start
      end
      
      def start
        'ifscript_up ${device} && cfg=0
         ifconfig_up ${ifn} && cfg=0
         ipv4_up ${ifn} && cfg=0
         ipx_up ${ifn} && cfg=0'
      end
      
      def stop
        'ipx_down ${ifn} && cfg=0
         ipv4_down ${ifn} && cfg=0
         #ifconfig_down
         if dhcpif $1; then
           /etc/rc.d/dhclient stop $1
           _cfg=0
         fi
         if ifexists $1; then
           ifconfig $1 down
           _cfg=0
         fi
         ifscript_down ${ifn} && cfg=0
        '

        #ipv4_down
        return true unless exists?
        inetList = run(:ifconfig, device).
          split("\n").select {|e| e =~ /inet / }#.
        #  map{|e| e = e.strip; e unless e.empty? }.compact
        inetList.each do |e|
          if e =~ /^.*(inet (?:[0-9]{1,3}\.){3}[0-9]{1,3}).*/
            execute :ifconfig, device, $1, 'delete'
          end
        end
          #ifalias_down ${_if} && _ret=0
          #ipv4_addrs_common ${_if} -alias && _ret=0
         
         #ifconfig_down
         _cfg = 1
         if exists?
           execute :ifconfig, device, 'down'
           _cfg = 0
         end
         _cfg
         
      end
    end
    class DhcpInterface < Interface
      attr_reader :dhcp_id
      
      def stop
        super
        execute '/etc/rc.d/dhclient', 'stop' device
      end
    end
  end
end