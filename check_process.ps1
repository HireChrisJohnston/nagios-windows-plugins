<#

.SYNOPSIS 
	Checks for a running process, if not running it will retun as a WARNING alert for Nagios
	
.DESCRIPTION 
	
    File Name  : check_process.ps1 
    Author     : Chris Johnston - HireChrisJohnston@gmail.com
    Requires   : PowerShell V2
    
	Specify the process using regular expressions knowing it uses where 'like' matching
	using the commandline switch. Even though the return code result is a WARNING, 
	the text output of the plugin indicates critical, this is not a mistake.  
	
.EXAMPLE 
	PS C:\> .\check_process.ps1 -process '*notepad*'
	
	OK: Process Running containing *notepad* in the commandline

	PS C:\> .\check_process.ps1 -process '*notepad'

	CRITICAL: Process containing (*notepad) in the commandline is not running
#>
param (
    [string]$process = "*notepad*"
)

$schedulerProcess = Get-WmiObject win32_process | where {$_.CommandLine -like $process}
$status_output

		
if($schedulerProcess.SessionID -gt 0) {
	$status_output = "OK: Process Running containing $process in the commandline"
	$returnCode = '0' 
	}
	else {
	$status_output = "CRITICAL: Process containing ($process) in the commandline is not running" 
	$returnCode = '1'
}
		
write-host $status_output
exit $returnCode
