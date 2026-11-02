

${HOME}/services/security/firewall/ufw/InitialiseFirewall.sh


${HOME}/services/security/firewall/ufw/KnickersUp.sh

${HOME}/services/security/firewall/ufw/SSHHardening.sh


${HOME}/services/security/firewall/ufw/DenyAuthenticator.sh


${HOME}/services/security/firewall/ufw.AllowWireguard.sh

${HOME}/services/security/firewall/ufw/AllowBuildMachine.sh


${HOME}/services/security/firewall/ufw/AllowVPC.sh

${HOME}/services/security/firewall/ufw/AllowCustomPorts.sh

${HOME}/services/security/firewall/ufw/ReloadFirewall.sh



        if ( [ "`/usr/bin/ufw status | /bin/grep 'inactive'`" = "" ] )
        then
                /bin/touch ${HOME}/runtime/FIREWALL-ACTIVE
        fi
