require 'spec_helper'

describe 'postgis' do

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge({
          :concat_basedir => '/var/lib/puppet/concat',
        })
      end

      context 'with postgis 1.5' do
        let :pre_condition do
          "class {'::postgresql::globals':
            encoding => 'UTF8',
            version => '9.1',
            postgis_version => '1.5',
          } ->
          class {'::postgresql::server':}"
        end

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('postgresql::server::postgis') }

        it do
          is_expected.to contain_postgresql__server__database('template_postgis').with({
            :istemplate => true,
            :template   => 'template1',
          })
        end

        script_path = case facts[:osfamily]
                      when 'Debian' then '/usr/share/postgresql/9.1/contrib/postgis-1.5'
                      when 'RedHat' then '/usr/pgsql-9.1/share/contrib/postgis-1.5'
                      end

        it do
          is_expected.to contain_exec('createlang plpgsql template_postgis').with({
            :user   => 'postgres',
            :unless => 'createlang -l template_postgis | grep -q plpgsql',
          }).that_requires('Postgresql::Server::Database[template_postgis]')
        end

        it do
          is_expected.to contain_exec("psql -q -d template_postgis -f #{script_path}/postgis.sql").with({
            :user   => 'postgres',
            :unless => 'echo "\dt" | psql -d template_postgis | grep -q geometry_columns',
          })
        end

        it do
          is_expected.to contain_exec("psql -q -d template_postgis -f #{script_path}/spatial_ref_sys.sql").with({
            :user   => 'postgres',
            :unless => 'test $(psql -At -d template_postgis -c "select count(*) from spatial_ref_sys") -ne 0',
          })
        end
      end

      context 'with postgis 2.1' do
        let :pre_condition do
          "class {'::postgresql::globals':
            encoding => 'UTF8',
            version => '9.1',
            postgis_version => '2.1',
          } ->
          class {'::postgresql::server':}"
        end

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('postgresql::server::postgis') }

        it do
          is_expected.to contain_postgresql__server__database('template_postgis').with({
            :istemplate => true,
            :template   => 'template1',
          })
        end

        it do
          is_expected.to contain_postgresql_psql('Add postgis extension on template_postgis').with({
            :db      => 'template_postgis',
            :command => 'CREATE EXTENSION postgis',
            :unless  => "SELECT extname FROM pg_extension WHERE extname = 'postgis'",
          }).that_requires('Postgresql::Server::Database[template_postgis]')
        end

        it do
          is_expected.to contain_postgresql_psql('Add postgis_topology extension on template_postgis').with({
            :db      => 'template_postgis',
            :command => 'CREATE EXTENSION postgis_topology',
            :unless  => "SELECT extname FROM pg_extension WHERE extname = 'postgis_topology'",
          })
        end
      end
    end
  end
end
