<?php
// Bootstrap the OSSN engine
define('OSSN_ALLOW_SYSTEM_START', true);
require_once('system/start.php');

$user = new OssnUser;
$user->username = 'XXXXWEBMASTER_USERNAMEXXXX';
$user->email = 'XXXXWEBMASTER_EMAILXXXX';
$user->password = 'XXXXWEBMASTER_PASSWORDXXXX';
$user->first_name = 'System';
$user->last_name = 'Administrator';
$user->validated = true;
$user->type = 'admin'; 

if ($user->addUser()) {
    echo "User created successfully!\n";
} else {
    echo "Failed to create user.\n";
}
?>
