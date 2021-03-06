class java (
  $source_url = "https://download.oracle.com/otn-pub/java/jdk/7u51-b13",
  $java_major_version = 7,
  $java_minor_version = 51,
  $additional_versions = {},
  $add_jce = true
  ) {

  include wget
  # Remove OpenJDK 6
  package {'java-1.6.0-openjdk':
    ensure   => absent,
  }

  # Remove OpenJDK 7
  package {'java-1.7.0-openjdk':
    ensure   => absent,
  }

  # Remove OpenJDK 8
  package {'java-1.8.0-openjdk':
    ensure   => absent,
  }

  # Configure JAVA_HOME globlly.
  file { '/etc/profile.d/java.sh':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => 644,
    content => "export JAVA_HOME=/usr/java/default",
  }

  define install_version ($major_minor=$title, $package_name=undef, $rpm_filename=undef, $source=$java::source_url, $add_jce=$java::add_jce) {
    $split_out = split($major_minor, "_")
    $major = $split_out[0]
    $minor = $split_out[1]

    if ($rpm_filename != '') {
      $java_filename = $rpm_filename
    } else {
      $java_filename = "jdk-${major}u${minor}-linux-x64.rpm"
    }

    if ($package_name != '') {
      $package_root_name = $package_name
    } else {
      if ($major == "7") {
        $package_root_name = "jdk"
      } else {
        $package_root_name = "jdk1.${major}.0_${minor}"
      }
    }

    # Download the jdk from location of choice
    wget::fetch { "jdk ${source}/$java_filename":
      source      => "${source}/$java_filename",
      destination => "/usr/local/$java_filename",
      timeout     => 0,
      verbose     => false,
    }

    package {"jdk 1.${major}.0_${minor}-fcs":
      name     => "${package_root_name}",
      provider => rpm,
      ensure   => "1.${major}.0_${minor}-fcs",
      source   => "/usr/local/$java_filename",
      require  => Wget::Fetch["jdk ${source}/$java_filename"],
    }

    # Add JCE
    if ( str2bool( $add_jce ) ) {
      class { 'java::jce':
        java_major_version  => "$major",
        jdk_path            => "/usr/java/jdk1.${major}.0_${minor}",
        require             => Package["jdk 1.${major}.0_${minor}-fcs"]
      }
    }
  }

  create_resources ( 'install_version', $additional_versions )
  install_version {"${java_major_version}_${java_minor_version}": }

  file { "default java":
    path    => '/usr/java/default',
    ensure  => 'link',
    mode    => '0755',
    target  => "/usr/java/jdk1.${java_major_version}.0_${java_minor_version}",
    require => Package["jdk 1.${java_major_version}.0_${java_minor_version}-fcs"]
  }
  $fetch_cert = hiera_hash('java::create_truststore', undef)
  if ($fetch_cert) {
    $_hostname = keys($fetch_cert)
    $_pass = $fetch_cert["$_hostname"][key]
    $_port = $fetch_cert["$_hostname"][port]
    class { 'java::create-truststore':
      hostname => $_hostname,
      port => $_port,
      passphrase => $_pass,
      require => File["/usr/java/default"]
    }
  }

}
