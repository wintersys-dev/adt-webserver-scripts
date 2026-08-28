
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
