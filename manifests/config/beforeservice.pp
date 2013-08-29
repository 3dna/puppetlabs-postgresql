# Class: postgresql::config::beforeservice
#
# Parameters:
#
#   [*firewall_supported*]      - Is the firewall supported?
#   [*ip_mask_deny_postgres_user*]   - ip mask for denying remote access for postgres user; defaults to '0.0.0.0/0',
#                                       meaning that all TCP access for postgres user is denied.
#   [*ip_mask_allow_all_users*]      - ip mask for allowing remote access for other users (besides postgres);
#                                       defaults to '127.0.0.1/32', meaning only allow connections from localhost
#   [*listen_addresses*]        - what IP address(es) to listen on; comma-separated list of addresses; defaults to
#                                    'localhost', '*' = all
#   [*ipv4acls*]                - list of strings for access control for connection method, users, databases, IPv4
#                                    addresses; see postgresql documentation about pg_hba.conf for information
#   [*ipv6acls*]                - list of strings for access control for connection method, users, databases, IPv6
#                                    addresses; see postgresql documentation about pg_hba.conf for information
#   [*pg_hba_conf_path*]        - path to pg_hba.conf file
#   [*postgresql_conf_path*]    - path to postgresql.conf file
#   [*manage_redhat_firewall*]  - boolean indicating whether or not the module should open a port in the firewall on
#                                    redhat-based systems; this parameter is likely to change in future versions.  Possible
#                                    changes include support for non-RedHat systems and finer-grained control over the
#                                    firewall rule (currently, it simply opens up the postgres port to all TCP connections).
#   [*manage_pg_hba_conf*]      - boolean indicating whether or not the module manages pg_hba.conf file.
#   [*persist_firewall_command*] - Command to persist firewall connections.
#   [*shared_buffers*]          - shared_buffers setting in postgresql.conf
#
# Actions:
#
# Requires:
#
# Usage:
#   This class is not intended to be used directly; it is
#   managed by postgresl::config.  It contains resources
#   that should be handled *before* the postgres service
#   has been started up.
#
#   class { 'postgresql::config::before_service':
#     ip_mask_allow_all_users    => '0.0.0.0/0',
#   }
#
class postgresql::config::beforeservice(
  $pg_hba_conf_path,
  $postgresql_conf_path,
  $firewall_supported         = $postgresql::params::firewall_supported,
  $ip_mask_deny_postgres_user = $postgresql::params::ip_mask_deny_postgres_user,
  $ip_mask_allow_all_users    = $postgresql::params::ip_mask_allow_all_users,
  $listen_addresses           = $postgresql::params::listen_addresses,
  $ipv4acls                   = $postgresql::params::ipv4acls,
  $ipv6acls                   = $postgresql::params::ipv6acls,
  $manage_redhat_firewall     = $postgresql::params::manage_redhat_firewall,
  $manage_pg_hba_conf         = $postgresql::params::manage_pg_hba_conf,
  $persist_firewall_command   = $postgresql::params::persist_firewall_command,
  $shared_buffers             = undef,
  $archive_mode               = undef,
  $archive_command            = undef,
  $archive_timeout            = undef,
  $shared_preload_libraries   = undef,
  $work_mem                   = undef,
  $maintenance_work_mem       = undef,
  $max_stack_depth            = undef,
  $hot_standby                = undef,
  $wal_level                  = undef,
  $max_wal_senders            = undef,
  $wal_keep_segments          = undef,
  $checkpoint_segments        = undef,
  $checkpoint_timeout         = undef,
  $checkpoint_completion_target = undef,
  $effective_cache_size       = undef,
  $log_destination            = undef,
  $logging_collector          = undef,
  $log_directory              = undef,
  $log_filename               = undef,
  $log_min_duration_statement = undef,
  $log_checkpoints            = undef,
  $log_connections            = undef,
  $log_disconnections         = undef,
  $log_line_prefix            = undef,
  $log_lock_waits             = undef,
  $log_temp_files             = undef,
  $track_activities           = undef,
  $track_counts               = undef,
  $max_connections            = undef,
  $auto_explain_log_min_duration = undef,
) inherits postgresql::params {


  File {
    owner  => $postgresql::params::user,
    group  => $postgresql::params::group,
  }

  if $manage_pg_hba_conf {
    # Create the main pg_hba resource
    postgresql::pg_hba { 'main':
      notify => Exec['reload_postgresql'],
    }

    Postgresql::Pg_hba_rule {
      database => 'all',
      user => 'all',
    }

    # Lets setup the base rules
    $auth_option = $postgresql::params::version ? {
      '8.1'   => 'sameuser',
      default => undef,
    }

    postgresql::pg_hba_rule { 'local access as postgres user':
      type        => 'local',
      user        => $postgresql::params::user,
      auth_method => 'ident',
      auth_option => $auth_option,
      order       => '001',
    }
    postgresql::pg_hba_rule { 'local access to database with same name':
      type        => 'local',
      auth_method => 'ident',
      auth_option => $auth_option,
      order       => '002',
    }
    postgresql::pg_hba_rule { 'deny access to postgresql user':
      type        => 'host',
      user        => $postgresql::params::user,
      address     => $ip_mask_deny_postgres_user,
      auth_method => 'reject',
      order       => '003',
    }

    # ipv4acls are passed as an array of rule strings, here we transform them into
    # a resources hash, and pass the result to create_resources
    $ipv4acl_resources = postgresql_acls_to_resources_hash($ipv4acls, 'ipv4acls', 10)
    create_resources('postgresql::pg_hba_rule', $ipv4acl_resources)

    postgresql::pg_hba_rule { 'allow access to all users':
      type        => 'host',
      address     => $ip_mask_allow_all_users,
      auth_method => 'md5',
      order       => '100',
    }
    postgresql::pg_hba_rule { 'allow access to ipv6 localhost':
      type        => 'host',
      address     => '::1/128',
      auth_method => 'md5',
      order       => '101',
    }

    # ipv6acls are passed as an array of rule strings, here we transform them into
    # a resources hash, and pass the result to create_resources
    $ipv6acl_resources = postgresql_acls_to_resources_hash($ipv6acls, 'ipv6acls', 102)
    create_resources('postgresql::pg_hba_rule', $ipv6acl_resources)
  }

  # We must set a "listen_addresses" line in the postgresql.conf if we
  #  want to allow any connections from remote hosts.
  file_line { 'postgresql.conf#listen_addresses':
    path        => $postgresql_conf_path,
    match       => '^listen_addresses\s*=.*$',
    line        => "listen_addresses = '${listen_addresses}'",
    notify      => Service['postgresqld'],
  }

  if ($shared_buffers) {
    file_line { 'postgresql.conf#shared_buffers':
      path   => $postgresql_conf_path,
      match  => '^shared_buffers\s*=.*$',
      line   => "shared_buffers = ${shared_buffers}",
      notify => Service['postgresqld']
    }
  }

  if ($archive_mode) {
    file_line { 'postgresql.conf#archive_mode':
      path   => $postgresql_conf_path,
      match  => '^archive_mode\s*=.*$',
      line   => "archive_mode = ${archive_mode}",
      notify => Service['postgresqld']
    }
  }

  if ($archive_command) {
    file_line { 'postgresql.conf#archive_command':
      path   => $postgresql_conf_path,
      match  => '^archive_command\s*=.*$',
      line   => "archive_command = '${archive_command}'",
      notify => Service['postgresqld']
    }
  }

  if ($archive_timeout) {
    file_line { 'postgresql.conf#archive_timeout':
      path   => $postgresql_conf_path,
      match  => '^archive_timeout\s*=.*$',
      line   => "archive_timeout = ${archive_timeout}",
      notify => Service['postgresqld']
    }
  }

  if ($shared_preload_libraries) {
    file_line { 'postgresql.conf#shared_preload_libraries':
      path   => $postgresql_conf_path,
      match  => '^shared_preload_libraries\s*=.*$',
      line   => "shared_preload_libraries = '${shared_preload_libraries}'",
      notify => Service['postgresqld']
    }
  }

  if ($work_mem) {
    file_line { 'postgresql.conf#work_mem':
      path   => $postgresql_conf_path,
      match  => '^work_mem\s*=.*$',
      line   => "work_mem = ${work_mem}",
      notify => Service['postgresqld']
    }
  }

  if ($maintenance_work_mem) {
    file_line { 'postgresql.conf#maintenance_work_mem':
      path   => $postgresql_conf_path,
      match  => '^maintenance_work_mem\s*=.*$',
      line   => "maintenance_work_mem = ${maintenance_work_mem}",
      notify => Service['postgresqld']
    }
  }

  if ($max_stack_depth) {
    file_line { 'postgresql.conf#max_stack_depth':
      path   => $postgresql_conf_path,
      match  => '^max_stack_depth\s*=.*$',
      line   => "max_stack_depth = ${max_stack_depth}",
      notify => Service['postgresqld']
    }
  }

  if ($hot_standby) {
    file_line { 'postgresql.conf#hot_standby':
      path   => $postgresql_conf_path,
      match  => '^hot_standby\s*=.*$',
      line   => "hot_standby = ${hot_standby}",
      notify => Service['postgresqld']
    }
  }

  if ($wal_level) {
    file_line { 'postgresql.conf#wal_level':
      path   => $postgresql_conf_path,
      match  => '^wal_level\s*=.*$',
      line   => "wal_level = ${wal_level}",
      notify => Service['postgresqld']
    }
  }

  if ($max_wal_senders) {
    file_line { 'postgresql.conf#max_wal_senders':
      path   => $postgresql_conf_path,
      match  => '^max_wal_senders\s*=.*$',
      line   => "max_wal_senders = ${max_wal_senders}",
      notify => Service['postgresqld']
    }
  }

  if ($wal_keep_segments) {
    file_line { 'postgresql.conf#wal_keep_segments':
      path   => $postgresql_conf_path,
      match  => '^wal_keep_segments\s*=.*$',
      line   => "wal_keep_segments = ${wal_keep_segments}",
      notify => Service['postgresqld']
    }
  }

  if ($checkpoint_segments) {
    file_line { 'postgresql.conf#checkpoint_segments':
      path   => $postgresql_conf_path,
      match  => '^checkpoint_segments\s*=.*$',
      line   => "checkpoint_segments = ${checkpoint_segments}",
      notify => Service['postgresqld']
    }
  }

  if ($checkpoint_timeout) {
    file_line { 'postgresql.conf#checkpoint_timeout':
      path   => $postgresql_conf_path,
      match  => '^checkpoint_timeout\s*=.*$',
      line   => "checkpoint_timeout = ${checkpoint_timeout}",
      notify => Service['postgresqld']
    }
  }

  if ($checkpoint_completion_target) {
    file_line { 'postgresql.conf#checkpoint_completion_target':
      path   => $postgresql_conf_path,
      match  => '^checkpoint_completion_target\s*=.*$',
      line   => "checkpoint_completion_target = ${checkpoint_completion_target}",
      notify => Service['postgresqld']
    }
  }

  if ($effective_cache_size) {
    file_line { 'postgresql.conf#effective_cache_size':
      path   => $postgresql_conf_path,
      match  => '^effective_cache_size\s*=.*$',
      line   => "effective_cache_size = ${effective_cache_size}",
      notify => Service['postgresqld']
    }
  }

  if ($log_destination) {
    file_line { 'postgresql.conf#log_destination':
      path   => $postgresql_conf_path,
      match  => '^log_destination\s*=.*$',
      line   => "log_destination = '${log_destination}'",
      notify => Service['postgresqld']
    }
  }

  if ($logging_collector) {
    file_line { 'postgresql.conf#logging_collector':
      path   => $postgresql_conf_path,
      match  => '^logging_collector\s*=.*$',
      line   => "logging_collector = ${logging_collector}",
      notify => Service['postgresqld']
    }
  }

  if ($log_directory) {
    file_line { 'postgresql.conf#log_directory':
      path   => $postgresql_conf_path,
      match  => '^log_directory\s*=.*$',
      line   => "log_directory = '${log_directory}'",
      notify => Service['postgresqld']
    }
  }

  if ($log_filename) {
    file_line { 'postgresql.conf#log_filename':
      path   => $postgresql_conf_path,
      match  => '^log_filename\s*=.*$',
      line   => "log_filename = '${log_filename}'",
      notify => Service['postgresqld']
    }
  }

  if ($log_min_duration_statements) {
    file_line { 'postgresql.conf#log_min_duration_statements':
      path   => $postgresql_conf_path,
      match  => '^log_min_duration_statements\s*=.*$',
      line   => "log_min_duration_statements = ${log_min_duration_statements}",
      notify => Service['postgresqld']
    }
  }

  if ($log_checkpoints) {
    file_line { 'postgresql.conf#log_checkpoints':
      path   => $postgresql_conf_path,
      match  => '^log_checkpoints\s*=.*$',
      line   => "log_checkpoints = ${log_checkpoints}",
      notify => Service['postgresqld']
    }
  }

  if ($log_connections) {
    file_line { 'postgresql.conf#log_connections':
      path   => $postgresql_conf_path,
      match  => '^log_connections\s*=.*$',
      line   => "log_connections = ${log_connections}",
      notify => Service['postgresqld']
    }
  }

  if ($log_disconnections) {
    file_line { 'postgresql.conf#log_disconnections':
      path   => $postgresql_conf_path,
      match  => '^log_disconnections\s*=.*$',
      line   => "log_disconnections = ${log_disconnections}",
      notify => Service['postgresqld']
    }
  }

  if ($log_line_prefix) {
    file_line { 'postgresql.conf#log_line_prefix':
      path   => $postgresql_conf_path,
      match  => '^log_line_prefix\s*=.*$',
      line   => "log_line_prefix = '${log_line_prefix}'",
      notify => Service['postgresqld']
    }
  }

  if ($log_lock_waits) {
    file_line { 'postgresql.conf#log_lock_waits':
      path   => $postgresql_conf_path,
      match  => '^log_lock_waits\s*=.*$',
      line   => "log_lock_waits = ${log_lock_waits}",
      notify => Service['postgresqld']
    }
  }

  if ($log_temp_files) {
    file_line { 'postgresql.conf#log_temp_files':
      path   => $postgresql_conf_path,
      match  => '^log_temp_files\s*=.*$',
      line   => "log_temp_files = ${log_temp_files}",
      notify => Service['postgresqld']
    }
  }

  if ($track_activities) {
    file_line { 'postgresql.conf#track_activities':
      path   => $postgresql_conf_path,
      match  => '^track_activities\s*=.*$',
      line   => "track_activities = ${track_activities}",
      notify => Service['postgresqld']
    }
  }

  if ($track_counts) {
    file_line { 'postgresql.conf#track_counts':
      path   => $postgresql_conf_path,
      match  => '^track_counts\s*=.*$',
      line   => "track_counts = ${track_counts}",
      notify => Service['postgresqld']
    }
  }

  if ($max_connections) {
    file_line { 'postgresql.conf#max_connections':
      path   => $postgresql_conf_path,
      match  => '^max_connections\s*=.*$',
      line   => "max_connections = ${max_connections}",
      notify => Service['postgresqld']
    }
  }

  if ($auto_explain_log_min_duration) {
    file_line { 'postgresql.conf#auto_explain_log_min_duration':
      path   => $postgresql_conf_path,
      match  => '^auto_explain\.log_min_duration\s*=.*$',
      line   => "auto_explain.log_min_duration = ${auto_explain_log_min_duration}",
      notify => Service['postgresqld']
    }
  }

  # Here we are adding an 'include' line so that users have the option of
  # managing their own settings in a second conf file. This only works for
  # postgresql 8.2 and higher.
  if(versioncmp($postgresql::params::version, '8.2') >= 0) {
    # Since we're adding an "include" for this extras config file, we need
    # to make sure it exists.
    exec { 'create_postgresql_conf_path':
      command => "touch `dirname ${postgresql_conf_path}`/postgresql_puppet_extras.conf",
      path    => '/usr/bin:/bin',
      unless  => "[ -f `dirname ${postgresql_conf_path}`/postgresql_puppet_extras.conf ]"
    }

    file_line { 'postgresql.conf#include':
      path        => $postgresql_conf_path,
      line        => 'include \'postgresql_puppet_extras.conf\'',
      require     => Exec['create_postgresql_conf_path'],
      notify      => Service['postgresqld'],
    }
  }


  # TODO: is this a reasonable place for this firewall stuff?
  # TODO: figure out a way to make this not platform-specific; debian and ubuntu have
  #        an out-of-the-box firewall configuration that seems trickier to manage
  # TODO: get rid of hard-coded port
  if ( $manage_redhat_firewall and $firewall_supported ) {
      exec { 'postgresql-persist-firewall':
        command     => $persist_firewall_command,
        refreshonly => true,
      }

      Firewall {
        notify => Exec['postgresql-persist-firewall']
      }

      firewall { '5432 accept - postgres':
        port   => '5432',
        proto  => 'tcp',
        action => 'accept',
      }
  }
}
