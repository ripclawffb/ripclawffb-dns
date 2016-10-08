# Configures DNS client settings
#
# HIERA DATA:
# Contains the DNS servers and suffixes
# profile::dns::cfg:
#   dns_servers: <Array of DNS servers>
#     - <DNS Server 1>
#     - <DNS Server 2>
#   search_suffix: <Array of DNS suffixes>
#     - <Suffix 1>
#     - <Suffix 2>
#
# HIERA EXAMPLE:
# profile::dns::cfg:
#   dns_servers:
#     - 8.8.8.8
#     - 4.2.2.2
#   search_suffix:
#     - domain1.local
#     - domain2.local
#
# MODULE DEPENDENCIES:
# puppet module install ghoneycutt-dnsclient
# puppet module install puppetlabs-dsc
# puppet module install puppetlabs-stdlib

class profile::dns {
  # hiera lookups
  # specifically did not do a hiera hash because it merges the array from multiple
  # hieras which will cause both dns entries to be included
  $cfg = hiera('profile::dns::cfg')

  # validate lookup
  validate_hash($cfg)

  # variable assignments
  $dns_servers = $cfg[dns_servers]
  $search_suffix = $cfg[search_suffix]
  $primary_interface = $::networking[primary]

  # validate variables
  validate_array($dns_servers, $search_suffix)
  validate_string($primary_interface)

  if ($::osfamily == 'windows') {
    # requires dsc

    if ($::networking[ip] == $dns_servers[0]) {
      # if host ip is the same as the first dns server, reverse the order
      # this will be true on domain controllers
      $reverse_dns_servers = concat(reverse($dns_servers),'127.0.0.1')

      # set dns client setings in reverse for domain controller
      dsc_xdnsserveraddress { $primary_interface:
        dsc_address        => $reverse_dns_servers,
        dsc_interfacealias => $primary_interface,
        dsc_addressfamily  => 'IPv4',
      }
    } else {
      # set dns client setings
      dsc_xdnsserveraddress { $primary_interface:
        dsc_address        => $dns_servers,
        dsc_interfacealias => $primary_interface,
        dsc_addressfamily  => 'IPv4',
      }
    }

    # setup dns suffix - not yet implemented by puppetlabs-dsc
    # dsc_xdnsclientglobalsetting { $primary_interface:
    #   dsc_suffixsearchlist => $search_suffix,
    #   dsc_usedevolution    => true,
    #   dsc_devolutionlevel  => 0,
    # }
  }

  if ($::osfamily == 'RedHat') {
    # set dns client setings
    class { '::dnsclient':
      nameservers => $dns_servers,
      search      => $search_suffix,
    }
  }
}
