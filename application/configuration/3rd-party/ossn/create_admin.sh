INSERT INTO `ossn_users` (
        `username`, 
        `email`, 
        `password`, 
        `salt`,
        `first_name`, 
        `last_name`, 
        `type`, 
        `last_login`,
        `last_activity`,
        `activation`, 
        `time_created`,
        `time_updated`
        ) VALUES (
                'XXXXWEBMASTER_USERNAMEXXXX', 
                'XXXXWEBMASTER_EMAILXXXX', 
                'XXXXWEBMASTER_PASSWORDXXXX', 
                'XXXXSALTXXXX',
                'System', 
                'Administrator', 
                'admin', 
                UNIX_TIMESTAMP(),
                UNIX_TIMESTAMP(),
                '', 
                UNIX_TIMESTAMP(),
                UNIX_TIMESTAMP()
                );
~                     
