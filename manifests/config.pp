# Class: postgresql::config
#
# Parameters:
#
#   [*postgres_password*]            - postgres db user password.
#   [*ip_mask_deny_postgres_user*]   - ip mask for denying remote access for postgres user; defaults to '0.0.0.0/0',
#                                       meaning that all TCP access for postgres user is denied.
#   [*ip_mask_allow_all_users*]      - ip mask for allowing remote access for other users (besides postgres);
#                                       defaults to '127.0.0.1/32', meaning only allow connections from localhost
#   [*listen_addresses*]             - what IP address(es) to listen on; comma-separated list of addresses; defaults to
#                                       'localhost', '*' = all
#   [*ipv4acls*]                     - list of strings for access control for connection method, users, databases, IPv4
#                                       addresses; see postgresql documentation about pg_hba.conf for information
#   [*ipv6acls*]                     - list of strings for access control for connection method, users, databases, IPv6
#                                       addresses; see postgresql documentation about pg_hba.conf for information
#   [*pg_hba_conf_path*]             - path to pg_hba.conf file
#   [*postgresql_conf_path*]         - path to postgresql.conf file
#   [*manage_redhat_firewall*]       - boolean indicating whether or not the module should open a port in the firewall on
#                                       redhat-based systems; this parameter is likely to change in future versions.  Possible
#                                       changes include support for non-RedHat systems and finer-grained control over the
#                                       firewall rule (currently, it simply opens up the postgres port to all TCP connections).
#   [*manage_pg_hba_conf*]      - boolean indicating whether or not the module manages pg_hba.conf file.
#
#
# Actions:
#
# Requires:
#
# Usage:
#
#   class { 'postgresql::config':
#     postgres_password         => 'postgres',
#     ip_mask_allow_all_users   => '0.0.0.0/0',
#   }
#
class postgresql::config(
  $postgres_password          = undef,
  $ip_mask_deny_postgres_user = $postgresql::params::ip_mask_deny_postgres_user,
  $ip_mask_allow_all_users    = $postgresql::params::ip_mask_allow_all_users,
  $listen_addresses           = $postgresql::params::listen_addresses,
  $ipv4acls                   = $postgresql::params::ipv4acls,
  $ipv6acls                   = $postgresql::params::ipv6acls,
  $pg_hba_conf_path           = $postgresql::params::pg_hba_conf_path,
  $postgresql_conf_path       = $postgresql::params::postgresql_conf_path,
  $manage_redhat_firewall     = $postgresql::params::manage_redhat_firewall,
  $manage_pg_hba_conf         = $postgresql::params::manage_pg_hba_conf,
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

  # Basically, all this class needs to handle is passing parameters on
  #  to the "beforeservice" and "afterservice" classes, and ensure
  #  the proper ordering.

  class { 'postgresql::config::beforeservice':
    ip_mask_deny_postgres_user => $ip_mask_deny_postgres_user,
    ip_mask_allow_all_users    => $ip_mask_allow_all_users,
    listen_addresses           => $listen_addresses,
    ipv4acls                   => $ipv4acls,
    ipv6acls                   => $ipv6acls,
    pg_hba_conf_path           => $pg_hba_conf_path,
    postgresql_conf_path       => $postgresql_conf_path,
    manage_redhat_firewall     => $manage_redhat_firewall,
    manage_pg_hba_conf         => $manage_pg_hba_conf,
    shared_buffers             => $shared_buffers,
    archive_mode               => $archive_mode,
    archive_command            => $archive_command,
    archive_timeout            => $archive_timeout,
    shared_preload_libraries   => $shared_preload_libraries,
    work_mem                   => $work_mem,
    maintenance_work_mem       => $maintenance_work_mem,
    max_stack_depth            => $max_stack_depth,
    hot_standby                => $hot_standby,
    wal_level                  => $wal_level,
    max_wal_senders            => $max_wal_senders,
    wal_keep_segments          => $wal_keep_segments,
    checkpoint_segments        => $checkpoint_segments,
    checkpoint_timeout         => $checkpoint_timeout,
    checkpoint_completion_target => $checkpoint_completion_target,
    effective_cache_size       => $effective_cache_size,
    log_destination            => $log_destination,
    logging_collector          => $logging_collector,
    log_directory              => $log_directory,
    log_filename               => $log_filename,
    log_min_duration_statement => $log_min_duration_statement,
    log_checkpoints            => $log_checkpoints,
    log_connections            => $log_connections,
    log_disconnections         => $log_disconnections,
    log_line_prefix            => $log_line_prefix,
    log_lock_waits             => $log_lock_waits,
    log_temp_files             => $log_temp_files,
    track_activities           => $track_activities,
    track_counts               => $track_counts,
    max_connections            => $max_connections,
    auto_explain_log_min_duration => $auto_explain_log_min_duration,
  }

  class { 'postgresql::config::afterservice':
    postgres_password        => $postgres_password,
  }

  Class['postgresql::config'] ->
      Class['postgresql::config::beforeservice'] ->
      Service['postgresqld'] ->
      Class['postgresql::config::afterservice']

}
