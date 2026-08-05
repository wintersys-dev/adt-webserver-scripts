if ( [ ! -d ${HOME}/logs/social_messenger_installation ] )
then
        /bin/mkdir -p ${HOME}/logs/social_messenger_installation
fi

log_file="social_messenger_out_`/bin/date | /bin/sed 's/ //g'`"
err_file="social_messenger_err_`/bin/date | /bin/sed 's/ //g'`"

/bin/echo "Log file is at: ${HOME}/logs/social_messenger_installation/${log_file}"
/bin/echo "Error file is at: ${HOME}/logs/social_messenger_installation/${err_file}"

exec 1>>${HOME}/logs/social_messenger_installation/${log_file}
exec 2>>${HOME}/logs/social_messenger_installation/${err_file}

if ( [ ! -d ${HOME}/runtime/downloads_work_area ] )
then
        /bin/mkdir -p ${HOME}/runtime/downloads_work_area
fi

/bin/rm -r ${HOME}/runtime/downloads_work_area/*

cd ${HOME}/runtime/downloads_work_area

social_messenger_git_branch="`/bin/grep "^SOCIAL-MESSENGER:git-branch:" ${HOME}/runtime/application.dat | /bin/sed 's/SOCIAL-MESSENGER:git-branch://g'`"
/bin/rm -r /var/www/html/
${HOME}/services/git/GitClone.sh "github" "" "Iqbolshoh" "php-social-messenger" "" "${social_messenger_git_branch}" "/var/www/html/social-messenger"
/bin/chown -R www-data:www-data /var/www/html
