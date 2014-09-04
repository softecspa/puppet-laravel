# == Define laravel::app
#
# This define install and configure an app instance
#
#
define laravel::app (
  $app_key,
  $source,
  $ensure           = 'present',
  $server_name      = $name,
  $server_port      = 80,
  $app_dir          = "/var/www/${name}",
  $owner            = $name,
  $group            = $name,
  $webuser          = 'www-data',
  $source_provider  = 'git',
  $source_username  = '',
  $source_password  = '',
  $mysql_host       = 'localhost',
  $mysql_user       = $name,
  $mysql_password   = $name,
  $mysql_dbname     = $name,
  $mysql_dump       = '',
  $clean_ephimerals = false,
  $app_debug        = false,
  $timezone         = 'UTC',
  $locale           = 'en',
  $fallback_locale  = 'en'
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
  validate_re($timezone, '[A-Z][a-z]+/[a-zA-z0-9\-+]+')
  validate_re($locale, '[a-z]{2}(_[A-Z]{2})?')
  validate_re($fallback_locale, '[a-z]{2}(_[A-Z]{2})?')

  $url = "http://${server_name}:${server_port}"

  # virtualhost document root, public files
  $root_dir    = "${app_dir}/public"
  # app generated files
  $var_dir     = "${app_dir}/app/storage"

  $webserver_writable_dirs = [
    $var_dir,
    "${var_dir}/logs",
    "${root_dir}/uploads",
  ]

  # webserver must write here and we can empty them on deploy
  $ephimeral_dirs = [
    "${var_dir}/cache",
    "${var_dir}/sessions",
    "${var_dir}/tmp",
    "${var_dir}/views",
    "${var_dir}/meta",
  ]

  file { $app_dir:
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => '2775',
  }

  file { $root_dir:
    ensure  => directory,
    owner   => $owner,
    group   => $group,
    mode    => '2775',
    require => Vcsrepo[$app_dir],
  }

  file { [ $webserver_writable_dirs, $ephimeral_dirs ]:
    ensure  => directory,
    owner   => $webuser,
    group   => $group,
    mode    => '2775',
    require => Vcsrepo[$app_dir],
  }

  if ($clean_ephimerals) {
    tidy { $ephimeral_dirs:
      recurse => true,
      rmdirs  => false,
      matches => '^[^.](.*)', # skip hidden files
      require => Vcsrepo[$app_dir],
    }
  }

  vcsrepo { $app_dir:
    ensure              => $ensure,
    source              => $source,
    provider            => $source_provider,
    basic_auth_username => $source_username,
    basic_auth_password => $source_password,
    owner               => $owner,
    group               => $group,
    require             => File[$app_dir],
  }


  # Laravel application setup
  file { "${app_dir}/app/config/app.php":
    ensure  => file,
    owner   => $owner,
    group   => $webuser,
    mode    => '0644',
    content => template('app.php.erb'),
    require => Vcsrepo[$app_dir],
  }
  file { "${app_dir}/app/config/database.php":
    ensure  => file,
    owner   => $owner,
    group   => $webuser,
    mode    => '0644',
    content => template('database.php.erb'),
    require => Vcsrepo[$app_dir],
  }

  # All execs must be executed from the application home
  # and by the Owner of the laravel app, so file permissions
  # permits user to modify anything created by composer or artisan
  Exec {
    cwd  => $app_dir,
    user => $owner,
  }

  ## Laravel one-time setup
  # Run composer install only if .lock file does not exists
  exec { "${name}-composer-install":
    command => 'composer install',
    creates => "${app_dir}/composer.lock",
    tries   => 2,
    require => Vcsrepo[$app_dir],
  }

  # TODO: make a find in /vendor for directories $mod/src/migrations
  # and run migrate for all modules that need it
  exec {
    [
      "${app_dir}/artisan migrate --package=cartalyst/sentry",
      "${app_dir}/artisan migrate --package=liebig/cron",
    ]:
    refreshonly => true,
    subscribe   => Exec[ "${name}-composer-install" ],
  }

  file { "${app_dir}/composer.lock":
    owner   => $owner,
    group   => $group,
    mode    => '0664',
    require => Exec["${name}-composer-install"],
  }

  # run composer and db migrations only if something change on versioned files
  exec { "${name}-composer-update":
    command     => 'composer update',
    refreshonly => true,
    onlyif      => "test -f ${app_dir}/composer.lock",
    subscribe   => Vcsrepo[$app_dir],
  }

  exec { "${name}-migrate":
    command     => "${app_dir}/artisan migrate",
    refreshonly => true,
    subscribe   => [
      Exec["${name}-composer-update"],
      Exec["${name}-composer-install"]
    ],
  }

  exec { "${name}-seed":
    command     => "${app_dir}/artisan db:seed",
    refreshonly => true,
    require     => Exec["${name}-migrate"],
    subscribe   => Exec["${name}-composer-install"],
  }

  # Run artisan only if composer updates something
  exec {
    [
      "${app_dir}/artisan cache:clear",
      "${app_dir}/artisan clear-compiled",
      "${app_dir}/artisan optimize",
    ]:
    refreshonly => true,
    subscribe   => Exec[ "${name}-composer-update" ],
  }
}