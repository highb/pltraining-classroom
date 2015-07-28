class classroom::master::tuning {
  assert_private('This class should not be called directly')

  include classroom::master::hiera

  # See https://tickets.puppetlabs.com/browse/PE-9704
  if $classroom::jruby_purge {
    $cert   = "${classroom::confdir}/ssl/certs/pe-internal-classifier.pem"
    $key    = "${classroom::confdir}/ssl/private_keys/pe-internal-classifier.pem"
    $cacert = "${classroom::confdir}/ssl/certs/ca.pem"
    $master = "https://${::fqdn}:8140"
    $api    = 'puppet-admin-api/v1/jruby-pool'

    cron { 'purge jruby pool':
      ensure  => 'present',
      command => "curl -i --cert ${cert} --key ${key} --cacert ${cacert} -X DELETE ${master}/${api}",
      minute  => ['0','10','20','30','40','50'],
      target  => 'root',
      user    => 'root',
    }
  }

  if $classroom::jvm_tuning_profile != false {

    case $classroom::jvm_tuning_profile {
      'lvm': {
        $amq_heap_mb                = '32'
        $master_Xmx                 = '256m'
        $master_Xms                 = '256m'
        $master_MaxPermSize         = '96m'
        $master_PermSize            = '96m'
        $puppetdb_Xmx               = '64m'
        $puppetdb_Xms               = '64m'
        $console_Xmx                = '64m'
        $console_Xms                = '64m'
        $jruby_max_active_instances = 1
        $delayed_job_workers        = 1
      }
      'minimal': {
        if $classroom::jruby_purge {
          $amq_heap_mb                = '32'
          $master_Xmx                 = '128m'
          $master_Xms                 = '128m'
          $master_MaxPermSize         = '96m'
          $master_PermSize            = '96m'
          $puppetdb_Xmx               = '64m'
          $puppetdb_Xms               = '64m'
          $console_Xmx                = '64m'
          $console_Xms                = '64m'
          $jruby_max_active_instances = 1
          $delayed_job_workers        = 1
        }
        else
        {
          fail('Minimal tuning profile requires `jruby_purge => true`.')
        }
      }
      'moderate': {

      }
      'aggressive': {
      }
      default : {
        fail("Unknown tuning level, choose one of: 'lvm', 'minimal', 'moderate', 'aggressive', false")
      }
    }

    file { "${classroom::codedir}/hieradata/tuning.yaml":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('classroom/tuning.yaml.erb'),
      before  => Class['puppet_enterprise::profile::master', 'puppet_enterprise::profile::console'],
    }
  }
}
