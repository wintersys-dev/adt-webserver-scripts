        /usr/bin/sudo -u www-data /usr/local/bin/composer require drush/drush --no-interaction 

        if ( [ -f ${webroot_directory}/vendor/bin/drush.php ] )
        then
                /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/bin/drush.php"> /usr/sbin/drush
                /bin/echo "/bin/chmod 755 ${webroot_directory}/vendor/drush/drush" >> /usr/sbin/drush
                /bin/echo "/usr/bin/php ${webroot_directory}/vendor/bin/drush.php \$@" >> /usr/sbin/drush
                /bin/chmod 750 /usr/sbin/drush
        fi
