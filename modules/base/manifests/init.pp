#
# Explicit stage for pre-initialization tasks.
#
# Some tasks need to be executed before everything else (especially APT
# repository configuration). We define an explicit stage here to avoid
# dependency issues.
#
stage { "base-prepare": before => Stage[main] }

# Parent class for all systems.
# Configure APT repositories and ensure freshness of packages.
class base {

  # Enable 100% puppet management.
  file { "/etc/puppet/puppet.conf":
    source => "puppet:///modules/base/puppet.conf",
  }
  file { "/etc/default/puppet":
    source => "puppet:///modules/base/puppet-default",
  }

  class { "base::apt::standard": stage => "base-prepare" }

  # MOTD configuration.
  file { "/etc/motd.tail":
    source => "puppet:///modules/base/motd.tail",
  }

  # Firewall configuration.
  include "firewall"

  # Locales configuration.
  file { "/etc/locale.gen":
    source => "puppet:///modules/base/locales/locale.gen",
    require => Package["locales"],
    notify => Exec["locale-gen"],
  }
  file { "/etc/default/locale":
    source => "puppet:///modules/base/locales/locale",
    require => Package["locales"],
  }
  exec { "locale-gen":
    path        => "/usr/bin:/bin:/usr/sbin:/sbin",
    command     => "locale-gen",
    refreshonly => true,
  }

  # Login configuration.
  package { "locales": }
  file { "/etc/login.defs":
    owner   => root,
    group   => root,
    mode    => 644,
    source  => "puppet:///modules/base/login.defs",
  }

  # Sudo configuration.
  package { "sudo":
    ensure => present,
  }
  file { "/etc/sudoers":
    owner   => root,
    group   => root,
    mode    => 440,
    source  => "puppet:///modules/base/sudoers",
    require => Package["sudo"],
  }

  # SSH configuration.
  package { "openssh-server":
    ensure => present,
  }
  service { "ssh":
    pattern => "/usr/sbin/sshd",
    hasrestart => true,
    hasstatus => true,
    require => Package["openssh-server"]
  }
  file { "/etc/ssh/sshd_config":
    source => "puppet:///modules/base/sshd_config",
    require => Package["openssh-server"],
    notify => Service["ssh"]
  }

  # Firewall configuration.
  firewall::rule::allow_servers { "ssh":
    protocol => tcp,
    port => ssh,
    servers => [ "0.0.0.0/0" ],
  }
}

#
# Standard APT configuration for the test bots.
#
class base::apt::standard {
  include base::apt

  base::apt::repository { "lenny":
    repository_source => "puppet:///modules/base/lenny.sources.list",
  }

  base::apt::repository { "backports":
    repository_source => "puppet:///modules/base/backports.sources.list",
    key_source => "puppet:///modules/base/backports.public.key",
    key_id => "16BA136C",
  }

  base::apt::repository { "drupal.org":
    repository_source => "puppet:///modules/base/drupal.sources.list",
    key_source => "puppet:///modules/base/drupal.public.key",
    key_id => "A19A51A2",
  }

  # Live dangerously.
  base::apt::repository { "php53":
    repository_source => "puppet://$servername/modules/testing_bot/php53.sources.list",
    key_source => "puppet://$servername/modules/testing_bot/php53.public.key",
    key_id => "A19A51A2",
  }
}
