# common configuration for all virtual classes
class classroom::virtual (
  String                            $control_repo,
  String                            $control_owner,
  Optional[String]                  $event_id           = undef,
  Optional[String]                  $event_pw           = undef,
  Boolean                           $offline            = $classroom::params::offline,
  Boolean                           $use_gitea          = $classroom::params::use_gitea,
  Array                             $plugin_list        = $classroom::params::plugin_list,
  Variant[Enum['reduced'], Boolean] $jvm_tuning_profile = $classroom::params::jvm_tuning_profile,
) inherits classroom::params {
  assert_private('This class should not be called directly')

  if $classroom::params::role == 'master' {
    include classroom::master::dependencies::rubygems

    # Configure Hiera and install a Hiera data file to tune PE
    class { 'classroom::master::tuning':
      jvm_tuning_profile => $jvm_tuning_profile,
    }

    # Configure performance logging
    include classroom::master::perf_logging

    # Set up gitea server
    include classroom::master::gitea

    if $offline or $use_gitea {
      $full_plugin_list = flatten([$base_plugin_list, "Gitea" ])
      $gitserver        = $classroom::params::gitserver['gitea']
    } else {
      $full_plugin_list = $plugin_list
      $gitserver        = $classroom::params::gitserver['github']
    }

    if $event_id {
      $session_id = pick($event_pw, regsubst($event_id, '^(\w*-)?(\w*)$', '\2'))
    }
    else {
      $session_id = $classroom::params::session_id
    }

    if 'Dashboard' in $full_plugin_list {
      include classroom::master::dependencies::dashboard
    }

    class { 'puppetfactory':
      plugins          => $full_plugin_list,
      controlrepo      => $control_repository,
      gitserver        => $gitserver,
      repomodel        => 'single',
      usersuffix       => $classroom::params::usersuffix,
      dashboard_path   => "${showoff::root}/courseware/_files/tests",
      session          => $session_id,
      privileged       => false,
    }

    class { 'classroom::master::codemanager':
      control_owner => $control_owner,
      control_repo  => 'classroom-control-vf.git',
      gitserver     => $gitserver,
    }

  } elsif $classroom::params::role == 'proxy' {
    include classroom::proxy

  } else {
    # if we ever have universal classification for virtual agents, it will go here
    include classroom::agent::hiera
    include classroom::agent::packages
    include classroom::agent::rubygems

    unless $osfamily == 'windows' {
      include classroom::agent::postfix_ipv4
    }
  }

  # configure gem installs
  class { 'classroom::gemrc':
    offline => $offline,
  }

  if $::osfamily == 'windows' {
    # TODO: copied from classroom::windows; we should refactor both classes for reusability
    user { 'Administrator':
      ensure => present,
      groups => ['Administrators'],
    }

    chocolateyfeature { 'allowEmptyChecksums':
      ensure => enabled,
    }
    Chocolateyfeature['allowEmptyChecksums'] -> Package<| provider == 'chocolatey' |>

    # Windows Agents
    class {'chocolatey':
      chocolatey_download_url => 'https://chocolatey.org/api/v2/package/chocolatey/0.10.3',
    }

    include classroom::windows::disable_esc
    include classroom::windows::enable_rdp
    include classroom::windows::geotrust
    include classroom::windows::rubygems_update
    windows_env { 'PATH=C:\Program Files\Puppet Labs\Puppet\sys\ruby\bin': }
  }

  # fix augeas lens until it's updated in PE
  include classroom::agent::augeas
}
