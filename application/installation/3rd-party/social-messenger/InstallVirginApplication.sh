if ( [ ! -d ${HOME}/logs/application_installation ] )
then
        /bin/mkdir -p ${HOME}/logs/application_installation
fi

exec 1>>${HOME}/logs/application_installation/social-messenger_out.log
exec 2>>${HOME}/logs/application_installation/social-messenger_err.log

if ( [ ! -d ${HOME}/runtime/downloads_work_area ] )
then
        /bin/mkdir -p ${HOME}/runtime/downloads_work_area
fi

/bin/rm -r ${HOME}/runtime/downloads_work_area/*

cd ${HOME}/runtime/downloads_work_area

socialmessenger_git_branch="`/bin/grep "^SOCIAL-MESSENGER:git-branch:" ${HOME}/runtime/application.dat | /bin/sed 's/SOCIAL-MESSENGER:git-branch://g'`"

${HOME}/services/git/GitClone.sh "github" "" "Iqbolshoh" "php-social-messenger" "" "main" "/var/www/html/social-messenger"
/bin/chown -R www-data:www-data /var/www/html
