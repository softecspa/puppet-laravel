# == Define laravel::app
#
# This define install and configure an app instance
#
define laravel::app (
  $app_key,
  $source,
  $ensure                           = 'present',
  $server_name                      = $name,
  $server_port                      = 80,
  $app_dir                          = "/var/www/${name}",
  $app_var                          = "/var/local/${name}",
  $public_dirname                   = 'public',
  $owner                            = $name,
  $group                            = $name,
  $webuser                          = 'www-data',
  $strict_permissions               = false,
  $source_provider                  = 'git',
  $source_username                  = '',
  $source_password                  = '',
  $mysql_host                       = 'localhost',
  $mysql_user                       = $name,
  $mysql_password                   = $name,
  $mysql_dbname                     = $name,
  $mysql_dump                       = '',
  $clean_ephimerals                 = false,
  $app_debug                        = false,
  $timezone                         = 'UTC',
  $locale                           = 'en',
  $fallback_locale                  = 'en',
  $backup_data                      = false,
  $backup_data_cron_prepend         = undef,
  $sync_data                        = false,
  $sync_data_cron_prepend           = undef,
  $sync_applog                      = false,
  $sync_applog_cron_prepend         = undef,
  $logship_applog                   = false,
  $backup_data_hour                 = undef,
  $backup_data_minute               = undef,
  $backup_data_monthday             = undef,
  $backup_data_month                = undef,
  $backup_data_weekday              = undef,
  $backup_data_mail_notify          = false,
  $backup_data_nagios_notify        = false,
  $backup_data_mail_success         = undef,
  $backup_data_mail_warning         = undef,
  $backup_data_mail_failure         = undef,
  $backup_data_nagios_service_host  = $::hostname,
  $backup_data_nagios_service_name  = "${name}_backup_data",
  $backup_data_export_doc           = false,
  $sync_data_hour                   = undef,
  $sync_data_minute                 = undef,
  $sync_data_monthday               = undef,
  $sync_data_month                  = undef,
  $sync_data_weekday                = undef,
  $sync_data_mail_notify            = false,
  $sync_data_nagios_notify          = false,
  $sync_data_mail_success           = undef,
  $sync_data_mail_warning           = undef,
  $sync_data_mail_failure           = undef,
  $sync_data_nagios_service_host    = $::hostname,
  $sync_data_nagios_service_name    = "${name}_sync_data",
  $sync_data_export_doc             = false,
  $sync_applog_hour                 = undef,
  $sync_applog_minute               = undef,
  $sync_applog_mail_notify          = false,
  $sync_applog_nagios_notify        = false,
  $sync_applog_mail_success         = undef,
  $sync_applog_mail_warning         = undef,
  $sync_applog_mail_failure         = undef,
  $sync_applog_nagios_service_host  = $::hostname,
  $sync_applog_nagios_service_name  = "${name}_sync_applog",
  $sync_applog_export_doc           = false,
  $logship_applog_data_collector    = undef,
  $logship_applog_destination       = undef,
  $logship_applog_log_file          = undef,
  $logship_applog_fluentd_pos_dir   = undef,
  $logship_applog_fluentd_type      = undef,
  $logship_applog_fluentd_format    = undef,
  $logship_applog_fluentd_match_config  = undef,
  $aws_key_id                           = undef,
  $aws_sec_key                          = undef,
  $logship_applog_s3_bucket             = undef,
  $logship_applog_s3_bucket_endpoint    = undef,
  $logship_applog_s3_path               = undef,
  $export_backup_doc_fragment      = undef,
  $backup_doc_fragment_path        = undef,
  $backup_doc_fragment_name         = undef,
  $backup_doc_format                = undef,
) {
  # validate parameters here
  if !(is_domain_name($server_name)) {
    fail("server_name must be a valid domain name, '${server_name}' is not valid")
  }
  if !(is_integer($server_port)) {
    fail("server_port must be an integer, '${server_port}' is not valid")
  }
  validate_re($app_key, '\w{32}', 'App key must be 32 characters long')
  validate_re($owner, '[a-z_][a-z0-9\-_]{0,31}', "App user ${owner} seems not valid")
  validate_re($group, '[a-z_][a-z0-9\-_]{0,31}', "App group ${group} seems not valid")
  validate_re($ensure, '(present|latest)', 'Possible values for ensure are \'present\' or \'latest\'')
  validate_re($webuser, '[a-z_][a-z0-9\-_]{0,31}', "Web server user ${webuser} seems not valid")
  validate_absolute_path($app_dir)

  validate_bool(str2bool($clean_ephimerals))
  validate_bool(str2bool($app_debug))
  validate_re($timezone, '[A-Z][a-z]+(/[a-zA-z0-9\-+]+)?')
  validate_re($locale, '[a-z]{2}(_[A-Z]{2})?')
  validate_re($fallback_locale, '[a-z]{2}(_[A-Z]{2})?')

  $url = "http://${server_name}:${server_port}"

  # virtualhost document root, public files
  $root_dir    = "${app_dir}/${public_dirname}"
  # app generated files
  $var_dir     = "${app_var}/storage"

  $webserver_writable_dirs = [
    $var_dir,
    "${var_dir}/logs",
  ]

  # webserver must write here and we can empty them on deploy
  $ephimeral_dirs = [
    "${var_dir}/cache",
    "${var_dir}/sessions",
    "${var_dir}/tmp",
    "${var_dir}/views",
    "${var_dir}/meta",
  ]

  $real_owner = $strict_permissions?{
    true  => 'root',
    false => $owner
  }

  $app_dir_mode = $strict_permissions?{
    true  => '0644',
    false => '0666'
  }

  $vendor_dir_mode = $strict_permissions?{
    true  => '2644',
    false => '2666'
  }

  $root_dir_mode = $strict_permissions?{
    true  => '2644',
    false => '2666'
  }

  exec{"create_${app_dir}":
    command => "mkdir ${app_dir}",
    creates => $app_dir
  }

  vcsrepo { $app_dir:
    ensure              => $ensure,
    source              => $source,
    provider            => $source_provider,
    basic_auth_username => $source_username,
    basic_auth_password => $source_password,
    owner               => $real_owner,
    group               => $group,
    require             => Exec["create_${app_dir}"],
  }

  if ! defined(File[$app_dir]) {
    file { $app_dir:
      ensure  => directory,
      owner   => $real_owner,
      group   => $group,
      ignore  => ['.svn', 'artisan$', 'vendor'],
      mode    => $app_dir_mode,
      recurse => true,
      require => Vcsrepo[$app_dir]
    }
  }

  file {"${app_dir}/vendor":
    ensure  => directory,
    owner   => $real_owner,
    group   => $group,
    mode    => $vendor_dir_mode,
    require => Vcsrepo[$app_dir]
  }

  file {"${app_dir}/artisan":
    owner   => $real_owner,
    group   => $group,
    mode    => 'u+x',
    require => Vcsrepo[$app_dir]
  }

  if ! defined(File[$root_dir]) {
    file { $root_dir:
      ensure  => directory,
      owner   => $real_owner,
      group   => $group,
      mode    => $root_dir_mode,
      require => Vcsrepo[$app_dir],
    }
  }

  file { [ $webserver_writable_dirs, $ephimeral_dirs ]:
    ensure  => directory,
    owner   => $webuser,
    group   => $group,
    mode    => '2775',
    require => Vcsrepo[$app_dir],
  }

  # TODO: questa è una porkata!
  if $::profile::lamp::sharedpath_enable {
    file { "${root_dir}/uploads":
      ensure => link,
      force => true,
      target => "${::profile::lamp::sharedpath_mountpoint}/$name/public/uploads",
      require => File["${::profile::lamp::sharedpath_mountpoint}/$name/public"],
    }
  } else {
    file { "${root_dir}/uploads":
      ensure  => directory,
      owner   => $webuser,
      group   => $group,
      mode    => '2775',
      require => Vcsrepo[$app_dir],
    }
  }

  if ($clean_ephimerals) {
    tidy { $ephimeral_dirs:
      recurse => true,
      rmdirs  => false,
      matches => '^[^.](.*)', # skip hidden files
      require => Vcsrepo[$app_dir],
    }
  }

  # Laravel application setup
  file { "${app_dir}/app/config/app.php~":
    ensure  => file,
    owner   => $owner,
    group   => $webuser,
    mode    => '0440',
    content => template('laravel/app.php.erb'),
    require => Vcsrepo[$app_dir],
  }

  file { "${app_dir}/app/config/database.php~":
    ensure  => file,
    owner   => $owner,
    group   => $webuser,
    mode    => '0440',
    content => template('laravel/database.php.erb'),
    require => Vcsrepo[$app_dir],
  }

  ## Laravel one-time setup
  # Run composer install only if .lock file does not exists
  exec { "${name}-composer-install":
    command     => 'composer install',
    environment => [ "COMPOSER_HOME=${app_dir}" ],
    creates     => "${app_dir}/composer.lock",
    cwd         => $app_dir,
    user        => $real_owner,
    timeout     => 900,
    require     => File["${app_dir}/vendor"]
  }
  # run composer update if install has already created lock file
  # and only if vcsrepo notify me any change
  exec { "${name}-composer-update":
    command     => 'composer update',
    environment => [ "COMPOSER_HOME=${app_dir}" ],
    refreshonly => true,
    onlyif      => "test -f ${app_dir}/composer.lock",
    cwd         => $app_dir,
    user        => $real_owner,
    require     => File["${app_dir}/vendor"]
  }

 
  # Each module installed with composer could have migrations
  # Each module migration have to be run before app migrations
  # using the command
  #     artisan migrate --package=AUTHOR/MODULE
  # Migrations directory are at fourth depth level from app_dir
  #     app_dir/vendor/AUTHOR/MODULE/src/migrations
  $find = "find vendor -mindepth 4 -maxdepth 4 -type d -name migrations -exec ls -ld {} \\;"
  # With awk we got the list of modules to apply artisan command in the format
  #     AUTHOR/MODULE
  $awk = "awk -F'/' '{ print $2 \"/\" $3 }'"
  # The xargs command, run the artisan command onetime foreach module
  exec { "${name}-modules-migrations":
    command     => "${find}|${awk}|xargs -0 ./artisan migrate --no-interaction --package=",
    refreshonly => true,
    logoutput   => true,
    cwd         => $app_dir,
    user        => $real_owner,
    require     => File["${app_dir}/artisan"]
  }

  exec { "${name}-migrate":
    command     => "${app_dir}/artisan migrate --no-interaction",
    refreshonly => true,
    cwd         => $app_dir,
    user        => $real_owner,
    require     => File["${app_dir}/artisan"]
  }

  exec { "${name}-seed":
    command     => "${app_dir}/artisan db:seed --no-interaction",
    refreshonly => true,
    cwd         => $app_dir,
    user        => $real_owner,
    require     => File["${app_dir}/artisan"]
  }

   # Run artisan only if composer updates something
  exec {
    [
      "${app_dir}/artisan cache:clear --no-interaction",
      "${app_dir}/artisan clear-compiled --no-interaction",
      "${app_dir}/artisan optimize --no-interaction",
    ]:
    refreshonly => true,
    subscribe   => Exec["${name}-composer-update"],
    cwd         => $app_dir,
    user        => $real_owner,
    require     => File["${app_dir}/artisan"]
  }

  Vcsrepo[$app_dir] ->
  Exec["${name}-composer-install"] ~>
  Exec["${name}-modules-migrations"] ~>
  Exec["${name}-migrate"] ~>
  Exec["${name}-seed"]

  Vcsrepo[$app_dir] ~>
  Exec["${name}-composer-update"] ~>
  Exec["${name}-modules-migrations"] ~>
  Exec["${name}-migrate"]

  # let app owner&group run composer update manually
  file { "${app_dir}/composer.lock":
    owner   => $real_owner,
    group   => $group,
    mode    => '0664',
    require => Exec["${name}-composer-install"],
  }

  

  $data_dirs_to_backup = [ "${root_dir}/uploads" ]
  if $backup_data {
    backups::archive{"${name}_data_backup":
      path                       => $data_dirs_to_backup,
      hour                       => $backup_data_hour,
      minute                     => $backup_data_minute,
      monthday                   => $backup_data_monthday,
      month                      => $backup_data_month,
      weekday                    => $backup_data_weekday,
      cron_prepend               => $backup_data_cron_prepend,
      notify_mail_enable         => $backup_data_mail_notify,
      notify_mail_success        => $backup_data_mail_success,
      notify_mail_warning        => $backup_data_mail_warning,
      notify_mail_failure        => $backup_data_mail_failure,
      notify_nagios_enable       => $backup_data_nagios_notify,
      notify_nagios_service_host => $backup_data_nagios_service_host,
      notify_nagios_service_name => $backup_data_nagios_service_name,
    }
    
    $ensure_doc_backup_data = 'present'
  } else {
    $ensure_doc_backup_data = 'absent'
  }

  $real_ensure_doc_backup_data = $export_backup_doc_fragment ? {
    false       => 'absent',
    default => $ensure_doc_backup_data
  }

  if $backup_data_cron_prepend {
    $data_backup_note = "exec only if: $backup_data_cron_prepend"
  } else {
    $data_backup_note = ''
  }

  #TODO: actually only S3 is supported in backups module. Make destination dinamic
  concat::fragment {"${backup_doc_format}_backup_data_${name}":
    ensure  => $real_ensure_doc_backup_data,
    target  => "${backup_doc_fragment_path}/${backup_doc_fragment_name}",
    content => template("laravel/doc/${backup_doc_format}_backup_data.erb"),
    order   => '31'
  }

  $data_dirs_to_sync = [ "${root_dir}/uploads" ]
  if $sync_data {
    backups::sync {"${name}_data_sync":
      path                       => $data_dirs_to_sync,
      s3_path                    => "${name}_data_sync",
      hour                       => $sync_data_hour,
      minute                     => $sync_data_minute,
      monthday                   => $sync_data_monthday,
      month                      => $sync_data_month,
      weekday                    => $sync_data_weekday,
      cron_prepend               => $sync_data_cron_prepend,
      notify_mail_enable         => $sync_data_mail_notify,
      notify_mail_success        => $sync_data_mail_success,
      notify_mail_warning        => $sync_data_mail_warning,
      notify_mail_failure        => $sync_data_mail_failure,
      notify_nagios_enable       => $sync_data_nagios_notify,
      notify_nagios_service_host => $sync_data_nagios_service_host,
      notify_nagios_service_name => $sync_data_nagios_service_name,
    }

    $ensure_doc_sync_data = 'present'
  } else {
    $ensure_doc_sync_data = 'absent'
  }

  $real_ensure_doc_sync_data = $export_backup_doc_fragment ? {
    false   => 'absent',
    default => $ensure_doc_sync_data
  }

  if $sync_data_cron_prepend {
    $data_sync_note = "exec only if: $sync_data_cron_prepend"
  } else {
    $data_sync_note = ''
  }

  #TODO: actually only S3 is supported in backups module. Make destination dinamic
  concat::fragment {"${backup_doc_format}_sync_data_${name}":
    ensure  => $real_ensure_doc_sync_data,
    target  => "${backup_doc_fragment_path}/${backup_doc_fragment_name}",
    content => template("laravel/doc/${backup_doc_format}_sync_data.erb"),
    order   => '32'
  }

  $applog_dirs  = [ "${var_dir}/logs" ]
  if $sync_applog {
    backups::sync {"${name}_applog_sync":
      path                       => $applog_dirs,
      s3_path                    => "${name}_applog_sync",
      hour                       => $sync_applog_hour,
      minute                     => $sync_applog_minute,
      cron_prepend               => $sync_applog_cron_prepend,
      notify_mail_enable         => $sync_applog_mail_notify,
      notify_mail_success        => $sync_applog_mail_success,
      notify_mail_warning        => $sync_applog_mail_warning,
      notify_mail_failure        => $sync_applog_mail_failure,
      notify_nagios_enable       => $sync_applog_nagios_notify,
      notify_nagios_service_host => $sync_applog_nagios_service_host,
      notify_nagios_service_name => $sync_applog_nagios_service_name,
    }

    $ensure_doc_sync_applog = 'present'
  } else {
    $ensure_doc_sync_applog = 'absent'
  }

  $real_ensure_doc_sync_applog = $export_backup_doc_fragment ? {
    false   => 'absent',
    default => $ensure_doc_sync_applog
  }

  if $sync_applog_cron_prepend {
    $applog_sync_note = "exec only if: $sync_applog_cron_prepend"
  } else {
    $applog_sync_note = ''
  }

  #TODO: actually only S3 is supported in backups module. Make destination dinamic
  concat::fragment {"${backup_doc_format}_sync_applog_${name}":
    ensure  => $real_ensure_doc_sync_applog,
    target  => "${backup_doc_fragment_path}/${backup_doc_fragment_name}",
    content => template("laravel/doc/${backup_doc_format}_sync_applog.erb"),
    order   => '33'
  }

  if $logship_applog {

    Exec {
      cwd  => undef,
      user => undef,
    }

    logship::manage {"${name}_app_log":
      log_path             => "${var_dir}/logs/${logship_applog_log_file}",
      data_collector       => $logship_applog_data_collector,
      destination          => $logship_applog_destination,
      fluentd_type         => $logship_applog_fluentd_type,
      fluentd_format       => $logship_applog_fluentd_format,
      fluentd_match_config => $logship_applog_fluentd_match_config,
      fluentd_pos_dir      => $logship_applog_fluentd_pos_dir,
      aws_key_id           => $aws_key_id,
      aws_sec_key          => $aws_sec_key,
      s3_bucket            => $logship_applog_s3_bucket,
      s3_endpoint          => $logship_applog_s3_bucket_endpoint,
      s3_path              => $logship_applog_s3_path,
    }
  }
}

