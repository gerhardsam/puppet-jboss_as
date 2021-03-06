# Class: jboss_as::install
# This class is responsible for deploying the JBoss AS tarball and installing it
# and its service. It is broken into three main parts:
#
#   1. Create the user that JBoss AS will run as
#   2. Copy the JBoss AS tarball from the Puppet master and extract it on the
#      node.
#   3. Install the init script to /etc/init.d and add the service to chkconfig.
#
class jboss_as::install {
  # Bring variables in-scope to improve readability
  $jboss_user  = $jboss_as::jboss_user
  $jboss_group = $jboss_as::jboss_group
  $jboss_home  = $jboss_as::jboss_home
  $jboss_dist  = $jboss_as::jboss_dist
  $staging_dir = $jboss_as::staging_dir

  Exec {
    path => ['/usr/bin', '/bin', '/sbin', '/usr/sbin'],
  }

  # Create the user that JBoss AS will run as
  user { $jboss_user:
    ensure     => present,
    shell      => '/bin/bash',
    membership => 'minimum',
    managehome => true,
  }

  # As of Puppet 2.7, we can't manage parent dirs. Since we have no way of
  # knowing what directory the user chose for staging, or how deep it is,
  # we have this ugly hack.
  exec { 'create_staging_dir':
    command => "mkdir -p ${staging_dir}",
    unless  => "test -d ${staging_dir}"
  }

  file { $jboss_home: ensure => directory }

  # Download the distribution tarball from the Puppet Master
  # and extract to $JBOSS_HOME
  file { "${staging_dir}/${jboss_dist}":
    ensure  => file,
    source  => "puppet:///modules/jboss_as/${jboss_dist}"
  }

  exec { 'extract':
    command => "tar zxf ${staging_dir}/${jboss_dist} --strip-components=1 -C ${jboss_home}",
    unless  => "test -d ${jboss_home}/standalone",
    require => File["${staging_dir}/${jboss_dist}", $jboss_home]
  }

  exec { 'set_permissions':
    command => "chown -R ${jboss_user}:${jboss_group} ${jboss_home}",
    unless  => "test -d ${jboss_home}/standalone",
    require => Exec['extract']
  }

  # Install the init scripts and the service to chkconfig / rc.d
  #
  # Because variable scope is inconsistent between Puppet 2.7 and 3.x,
  # we need to redefine the JBOSS_HOME variable within this scope.
  # For more info, see http://docs.puppetlabs.com/guides/templating.html
  $this_jboss_home        = $jboss_home
  $initscript_template    = $jboss_as::params::initscript_template
  $initscript_install_cmd = $jboss_as::params::initscript_install_cmd

  file { '/etc/init.d/jboss-as':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template("jboss_as/${initscript_template}")
  }

  exec { 'install_service':
    command => $initscript_install_cmd,
    require => File['/etc/init.d/jboss-as'],
    unless  => 'test -f /etc/init.d/jboss-as'
  }
}
