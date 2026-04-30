<?php
  $ipaddress = $_POST["email"];
  $file="/tmp/ipaddresses.dat";
  $data = "$email\n";
  file_put_contents($file, $data, FILE_APPEND );
  echo "<h2>Wireguard access for your client has been requested</h2>";
?>
