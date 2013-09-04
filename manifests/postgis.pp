# Class: postgresql::postgis
#
# This class installs the postgresql postgis package
#
# Parameters:
#   [*package_name*]    - The name of the postgresql postgis package.
#   [*package_ensure*]  - The ensure value of the package.
#   [*scripts_package_name*]    - The name of the postgresql postgis-scripts package.
#   [*scripts_package_ensure*]  - The ensure value of the scripts package.
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
#   class { 'postgresql::postgis': }
#
class postgresql::contrib (
  $package_name   = $postgresql::params::postgis_package_name,
  $package_ensure = 'present',
  $scripts_package_name = $postgresql::params::postgis_scripts_package_name,
  $scripts_package_ensure = 'present',
) inherits postgresql::params {

  validate_string($package_name)

  package { 
    'postgresql-postgis':
      ensure => $package_ensure,
      name   => $package_name,
      tag    => 'postgresql';
    'postgresql-postgis-scripts':
      ensure => $scripts_package_ensure,
      name   => $scripts_package_name,
      tag    => 'postgresql';
  }

}
