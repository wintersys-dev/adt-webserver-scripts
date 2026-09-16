INSERT INTO `ossn_users` (
    `username`, 
    `email`, 
    `password`, 
    `first_name`, 
    `last_name`, 
    `type`, 
    `activated`, 
    `time_created`
) VALUES (
    'XXXXWEBMASTER_USERNAMEXXXX', 
    'XXXXWEBMASTER_EMAILXXXX', 
    'XXXXWEBMASTER_PASSWORDXXXX', 
    'System', 
    'Administrator', 
    'admin', 
    1, 
    UNIX_TIMESTAMP()
);
