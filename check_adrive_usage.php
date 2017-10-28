#!/usr/bin/php
<?php

/*

check_adrive_usage.php - Nagios plugin for checking ADrive disk usage
using the API.  Refer to API reference regarding API access restrictions 
based on account type.

USAGE:
.\check_adrive_usage.php  user@email.com UserPasword

# Written by Chris Johnston
# HireChrisJohnston@gmail.com

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details. 
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA. 

*/


if ($argv[1]) {
	$email		= $argv[1];
	$password 	= $argv[2];
	$warn 	= $argv[3];
	$crit 	= $argv[4];
} else {
	help();
	exit(4);
}

if(!$warn) {$warn=90;}
if(!$crit) {$crit=97;}
$exitCode=4;

$pool;
$total;
$used;
$avail;
$percentUsed;
$status;

$time=microtime();
$cookie_jar = "/tmp/ADrvCookie.$time";


//echo "Login";
//print_r($data_string);
//echo "Pool: " . $pool . "\n";
$data = array("email" => $email);
$data_string = array("json" => json_encode($data));
//echo "Get Pool";
$ch = curl_init('https://www.adrive.com/API/getPoolHost');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
//execute post and place results in $poolJson variable
$poolJson = curl_exec($ch);
//echo "The return value is: " . $poolJson . "\n";
//close connection
//curl_close($ch);

$poolArray = json_decode($poolJson);
$pool = $poolArray -> pool;

//echo "The pool is $pool";

//Login
$ch = curl_init("https://" . $pool . "/API/login");
$data = array("email" => $email, "password" => $password, "forceLogout" => "1");
$data_string = array("json" => json_encode($data));
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIEJAR, $cookie_jar);
$result = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE); 
$json = json_decode($result);
//print "Login Status: $result";
$ADriveMsg;
$ADriveMsg = $json -> messages[0];

if(preg_match("/error/i", $ADriveMsg[0])) {
print "Unable to Login!! Check the credentials - $ADriveMsg[1]";
exit(3);
}
//print_r($result);
//close connection
//curl_close($ch);
//End Login


//Get Disk use
$ch = curl_init("https://" . $pool . "/API/getUsage");
$data = array("email" => $email, "password" => $password);
$data_string = array("json" => json_encode($data));
$data_string = '{ }';
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIEFILE, $cookie_jar);
$result = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE); 
//echo "The return value is: " . $result . "\n";
//echo "\n GetUsage STATUS: $status";
//print_r($result);
//curl_close($ch);


$json = json_decode($result);
sscanf($json -> total, "%f GB", $Total);
sscanf($json -> used, "%f GB", $Used);
sscanf($json -> available, "%f GB", $Avail);
$percentUsed = $json -> du;


//Logout
$ch = curl_init("https://" . $pool . "/API/logout");
$data_string = '{ }';
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIEFILE, $cookie_jar);
$result = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE); 
//echo "\n Logout STATUS: $status";
//print_r($result);

//Close connections
curl_close($ch);
unlink($cookie_jar);

if($percentUsed<=$warn) {
	$status = 'OK';
	$exitCode = 0;
	}
IF ($percentUsed>$warn) {
		$status = 'WARNING';
		$exitCode = 1;
	}
If ($percentUsed>$crit) {
		$status= 'CRITICAL';
		$exitCode =2;
	}
	
$warn = ($warn /100) * $Total;
$crit = ($crit /100) * $Total;
$UsedGB = $Used.'GB';
$AvailGB = $Avail.'GB';
$TotalGB = $Total.'GB';

function help() {
print "\n\n USAGE:
.\check_adrive_usage.php  user@email.com UserPasword \n";
}

print "$status: $AvailGB Avail of $TotalGB [$percentUsed%]|'Total'=$TotalGB;0;0;$Total 'Used'=$UsedGB;$warn;$crit;$Total";
exit($exitCode);

?>