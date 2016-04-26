# Class: postgis
class postgis {

  class { '::postgresql::server::postgis': }
  ->
  postgresql::server::database { 'template_postgis':
    istemplate => true,
    template   => 'template1',
  }

  if versioncmp($::postgresql::globals::globals_version, '9.1') >= 0 and versioncmp($::postgresql::globals::globals_postgis_version, '2.0') >= 0 {
    postgresql_psql {'Add postgis extension on template_postgis':
      db      => 'template_postgis',
      command => 'CREATE EXTENSION postgis',
      unless  => "SELECT extname FROM pg_extension WHERE extname = 'postgis'",
      require => Postgresql::Server::Database['template_postgis'],
    } ->
    postgresql_psql {'Add postgis_topology extension on template_postgis':
      db      => 'template_postgis',
      command => 'CREATE EXTENSION postgis_topology',
      unless  => "SELECT extname FROM pg_extension WHERE extname = 'postgis_topology'",
    }
  }
  else {
    $script_path = $::osfamily ? {
      'Debian' => $::postgresql::globals::globals_version ? {
        '8.3'   => '/usr/share/postgresql-8.3-postgis',
        default => "/usr/share/postgresql/${::postgresql::globals::globals_version}/contrib/postgis-${::postgresql::globals::globals_postgis_version}",
      },
      'RedHat' => "/usr/pgsql-${::postgresql::globals::globals_version}/share/contrib/postgis-${::postgresql::globals::globals_postgis_version}",
    }
    Exec {
      path => ['/usr/bin', '/bin', ],
    }
    exec { 'createlang plpgsql template_postgis':
      user    => 'postgres',
      unless  => 'createlang -l template_postgis | grep -q plpgsql',
      require => Postgresql::Server::Database['template_postgis'],
    } ->
    exec { "psql -q -d template_postgis -f ${script_path}/postgis.sql":
      user   => 'postgres',
      unless => 'echo "\dt" | psql -d template_postgis | grep -q geometry_columns',
    } ->
    exec { "psql -q -d template_postgis -f ${script_path}/spatial_ref_sys.sql":
      user   => 'postgres',
      unless => 'test $(psql -At -d template_postgis -c "select count(*) from spatial_ref_sys") -ne 0',
    }
  }

}
