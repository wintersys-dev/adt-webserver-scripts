<?php
// Bootstrap the OSSN engine
define('OSSN_ALLOW_SYSTEM_START', true);
require_once('system/start.php');

$user = new OssnUser;
$user->username = 'newuser1';
$user->email = 'user@example.com1';
$user->password = 'SecurePassword123';
$user->first_name = 'John';
$user->last_name = 'Doe';
$user->validated = true;
$user->type = 'administrator'; // Use 'admin' for an administrator account

if ($user->addUser()) {
    echo "User created successfully!\n";
} else {
    echo "Failed to create user.\n";
}
?>
