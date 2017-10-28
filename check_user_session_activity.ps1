<#
.SYNOPSIS 
	Nagios check plugin used for monitoring user counts and group them by activity of active (5min or less), 15min, 30min, 45min and 45+min idle users.
	Output includes Nagios performance data for charting
	
.DESCRIPTION 

	Performance data is output by default.
	No alerts occur with the plugin at this time. It is used for performance charting and informational only.
	Perfect for layering in Nagios XI Graph Explorer
	
	Grouping of users by their idle status from Windows RDS (Remote Desktop Server)
	which has a maximum inactivity value of 1 minute before being considered idle:
		Working Users(Active) 	= Less than 4 min idle or in active status reported by RDS
		15min 					= 5-15min idle
		30min				 	= 16-30min idle
		45min				 	= 31-45min idle
		45plus					= more than 46min idle
		
		
    File Name  : check_user_session_activity.ps1 
    Author     : Chris Johnston - HireChrisJohnston@gmail.com
    Requires   : PowerShell V2
	License	   : MIT
    
	Alerts occur based on performance data for Privileges and Total Processor Time
	Includes charting the Maximum CPU samples observed over the collection of samples
	to further enhance and provide detail to CPU utilization.
	
	Usage is calculated across all cores for total CPU usage.  Adjust the variables as needed for changing the sampling method
	or thresholds from the default via command line
	
		-15warn 		Warning Threshold of 0-15min idle users (not used)
		-30warn 		Warning Threshold of 15-30min idle users (not used)
		-45warn 		Warning Threshold of 30-45min idle users (not used)
		-45pluswarn 	Warning Threshold of 45min or more idle users (not used)
		
	Nagios Performance data example seen below and has been formatted for readability of the performance metrics.

.REQUIRES
	Remote Desktop Services to count the active users and group them by idle time 
	Outputs HTML so you must enable that Nagios option
	Admin -> System Settings and check the "Allow HTML Tags in Host/Service Status" 
	or 
	set escape_html_tags=0 in your cgi.cfg

	
.EXAMPLE 
	PS C:\foo> .\check_user_session_activity.ps1 -15warn 500 -30warn 500 -45warn 500 -45pluswarn 500
	
	PS C:\foo> .\check_user_session_activity.ps1
	
	Active Users 15min or under: 92 (37 Working)
	<br />============================
	<br />15min-30min Idle: 5
	<br />30min-45min Idle: 3
	<br />============================
	<br />45min Plus Idle: 10|
	'Under15min_Idle'=0;100;;;
	'Working_Users'=0;;;;
	'15_30min_Idle'=0;100;;;
	'30_45min_Idle'=0;100;;;
	'45min_Plus_Idle'=0;100;;;

.LINK
	https://github.com/HireChrisJohnston/nagios-windows-plugins

#>
param (
    [int]$15warn = '500', 
    [int]$30warn = '500',
    [int]$45warn= '500',
    [int]$45pluswarn = '500'
)

function Get-UserSession {
<#  
.SYNOPSIS  
    Retrieves all user sessions from local or remote computers(s)

.DESCRIPTION
    Retrieves all user sessions from local or remote computer(s).
    
    Note:   Requires query.exe in order to run
    Note:   This works against Windows Vista and later systems provided the following registry value is in place
            HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\AllowRemoteRPC = 1
    Note:   If query.exe takes longer than 15 seconds to return, an error is thrown and the next computername is processed.  Suppress this with -erroraction silentlycontinue
    Note:   If $sessions is empty, we return a warning saying no users.  Suppress this with -warningaction silentlycontinue

.PARAMETER computername
    Name of computer(s) to run session query against
              
.parameter parseIdleTime
    Parse idle time into a timespan object

.parameter timeout
    Seconds to wait before ending query.exe process.  Helpful in situations where query.exe hangs due to the state of the remote system.
                    
.FUNCTIONALITY
    Computers

.EXAMPLE
    Get-usersession -computername "server1"

    Query all current user sessions on 'server1'

.EXAMPLE
    Get-UserSession -computername $servers -parseIdleTime | ?{$_.idletime -gt [timespan]"1:00"} | ft -AutoSize

    Query all servers in the array $servers, parse idle time, check for idle time greater than 1 hour.

.NOTES
    Thanks to Boe Prox for the ideas - http://learn-powershell.net/2010/11/01/quick-hit-find-currently-logged-on-users/

.LINK
    http://gallery.technet.microsoft.com/Get-UserSessions-Parse-b4c97837

#> 
    [cmdletbinding()]
    Param(
        [Parameter(
            Position = 0,
            ValueFromPipeline = $True)]
        [string[]]$ComputerName = "localhost",

        [switch]$ParseIdleTime,

        [validaterange(0,120)]
        [int]$Timeout = 15
    )             
    Process
    {
        ForEach($computer in $ComputerName)
        {
        
            #start query.exe using .net and cmd /c.  We do this to avoid cases where query.exe hangs

                #build temp file to store results.  Loop until we see the file
                    Try
                    {
                        $Started = Get-Date
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        
                        Do{
                            start-sleep -Milliseconds 300
                            
                            if( ((Get-Date) - $Started).totalseconds -gt 10)
                            {
                                Throw "Timed out waiting for temp file '$TempFile'"
                            }
                        }
                        Until(Test-Path -Path $tempfile)
                    }
                    Catch
                    {
                        Write-Error "Error for '$Computer': $_"
                        Continue
                    }

                #Record date.  Start process to run query in cmd.  I use starttime independently of process starttime due to a few issues we ran into
                    $Started = Get-Date
                    $p = Start-Process -FilePath C:\windows\system32\cmd.exe -ArgumentList "/c query user /server:$computer > $tempfile" -WindowStyle hidden -passthru

                #we can't read in info or else it will freeze.  We cant run waitforexit until we read the standard output, or we run into issues...
                #handle timeouts on our own by watching hasexited
                    $stopprocessing = $false
                    do
                    {
                    
                        #check if process has exited
                            $hasExited = $p.HasExited
                
                        #check if there is still a record of the process
                            Try
                            {
                                $proc = Get-Process -id $p.id -ErrorAction stop
                            }
                            Catch
                            {
                                $proc = $null
                            }

                        #sleep a bit
                            start-sleep -seconds .5

                        #If we timed out and the process has not exited, kill the process
                            if( ( (Get-Date) - $Started ).totalseconds -gt $timeout -and -not $hasExited -and $proc)
                            {
                                $p.kill()
                                $stopprocessing = $true
                                Remove-Item $tempfile -force
                                Write-Error "$computer`: Query.exe took longer than $timeout seconds to execute"
                            }
                    }
                    until($hasexited -or $stopProcessing -or -not $proc)
                    
                    if($stopprocessing)
                    {
                        Continue
                    }

                    #if we are still processing, read the output!
                        try
                        {
                            $sessions = Get-Content $tempfile -ErrorAction stop
                            Remove-Item $tempfile -force
                        }
                        catch
                        {
                            Write-Error "Could not process results for '$computer' in '$tempfile': $_"
                            continue
                        }
        
            #handle no results
            if($sessions){

                1..($sessions.count - 1) | Foreach-Object {
            
                    #Start to build the custom object
                    $temp = "" | Select ComputerName, Username, SessionName, Id, State, IdleTime, LogonTime
                    $temp.ComputerName = $computer

                    #The output of query.exe is dynamic. 
                    #strings should be 82 chars by default, but could reach higher depending on idle time.
                    #we use arrays to handle the latter.

                    if($sessions[$_].length -gt 5){
                        
                        #if the length is normal, parse substrings
                        if($sessions[$_].length -le 82){
                           
                            $temp.Username = $sessions[$_].Substring(1,22).trim()
                            $temp.SessionName = $sessions[$_].Substring(23,19).trim()
                            $temp.Id = $sessions[$_].Substring(42,4).trim()
                            $temp.State = $sessions[$_].Substring(46,8).trim()
                            $temp.IdleTime = $sessions[$_].Substring(54,11).trim()
                            $logonTimeLength = $sessions[$_].length - 65
                            try{
                                $temp.LogonTime = Get-Date $sessions[$_].Substring(65,$logonTimeLength).trim() -ErrorAction stop
                            }
                            catch{
                                #Cleaning up code, investigate reason behind this.  Long way of saying $null....
                                $temp.LogonTime = $sessions[$_].Substring(65,$logonTimeLength).trim() | Out-Null
                            }

                        }
                        
                        #Otherwise, create array and parse
                        else{                                       
                            $array = $sessions[$_] -replace "\s+", " " -split " "
                            $temp.Username = $array[1]
                
                            #in some cases the array will be missing the session name.  array indices change
                            if($array.count -lt 9){
                                $temp.SessionName = ""
                                $temp.Id = $array[2]
                                $temp.State = $array[3]
                                $temp.IdleTime = $array[4]
                                try
                                {
                                    $temp.LogonTime = Get-Date $($array[5] + " " + $array[6] + " " + $array[7]) -ErrorAction stop
                                }
                                catch
                                {
                                    $temp.LogonTime = ($array[5] + " " + $array[6] + " " + $array[7]).trim()
                                }
                            }
                            else{
                                $temp.SessionName = $array[2]
                                $temp.Id = $array[3]
                                $temp.State = $array[4]
                                $temp.IdleTime = $array[5]
                                try
                                {
                                    $temp.LogonTime = Get-Date $($array[6] + " " + $array[7] + " " + $array[8]) -ErrorAction stop
                                }
                                catch
                                {
                                    $temp.LogonTime = ($array[6] + " " + $array[7] + " " + $array[8]).trim()
                                }
                            }
                        }

                        #if specified, parse idle time to timespan
                        if($parseIdleTime){
                            $string = $temp.idletime
                
                            #quick function to handle minutes or hours:minutes
                            function Convert-ShortIdle {
                                param($string)
                                if($string -match "\:"){
                                    [timespan]$string
                                }
                                else{
                                    New-TimeSpan -Minutes $string
                                }
                            }
                
                            #to the left of + is days
                            if($string -match "\+"){
                                $days = New-TimeSpan -days ($string -split "\+")[0]
                                $hourMin = Convert-ShortIdle ($string -split "\+")[1]
                                $temp.idletime = $days + $hourMin
                            }
                            #. means less than a minute
                            elseif($string -like "." -or $string -like "none"){
                                $temp.idletime = [timespan]"0:00"
                            }
                            #hours and minutes
                            else{
                                $temp.idletime = Convert-ShortIdle $string
                            }
                        }
                
                        #Output the result
                        $temp
                    }
                }
            }            
            else
            {
                Write-Warning "'$computer': No sessions found"
            }
        }
    }
}
$sessObj = Get-UserSession -parseidletime
# 5 Min or Under
$sessActivework = $sessObj | ?{$_.IdleTime -le [timespan]"00:05" -and $_.State -eq 'Active' -and $_.Username -ne 'administrator'}

#$ 15 Min or Under
$sess15includeActive = $sessObj | ?{$_.IdleTime -ge [timespan]"00:00" -and $_.IdleTime -le [timespan]"00:15" -and $_.State -eq 'Active' -and $_.Username -ne 'administrator'}

# 15min or Under Excluding 5min or Under ( 15min active)
$sess15 =$sessObj | ?{$_.IdleTime -ge [timespan]"00:06" -and $_.IdleTime -le [timespan]"00:15" -and $_.State -eq 'Active' -and $_.Username -ne 'administrator'}

# 30min or under 
$sess30 =$sessObj | ?{$_.IdleTime -ge [timespan]"00:16" -and $_.IdleTime -le [timespan]"00:30" -and $_.State -eq 'Active' -and $_.Username -ne 'administrator'}
$sess45 =$sessObj | ?{$_.IdleTime -ge [timespan]"00:31" -and $_.IdleTime -le [timespan]"00:45" -and $_.State -eq 'Active' -and $_.Username -ne 'administrator'}
$sess45Plus =$sessObj | ?{$_.IdleTime -ge [timespan]"00:45" -and $_.State -eq 'Active' -and $_.Username -ne 'administrator'}
$measureactivework = $sessactivework | Measure-Object 
$measure15Include = $sess15IncludeActive | Measure-Object 
$measure15 = $sess15 | Measure-Object 
$measure30 = $sess30 | Measure-Object 
$measure45 = $sess45 | Measure-Object 
$measure45Plus = $sess45Plus | Measure-Object 

$activeWorking = $measureActiveWork.Count
$15IncludeActive = $measure15Include.Count
$15 = $measure15.Count
$30 = $measure30.Count
$45 = $measure45.Count
$45Plus = $measure45Plus.Count

Write-host "Active Users 15min or under: $15IncludeActive ($activeWorking Working)
<br />============================
<br />15min-30min Idle: $30
<br />30min-45min Idle: $45
<br />============================
<br />45min Plus Idle: $45plus|'Under15min_Idle'=$15IncludeActive;$15warn;;; 'Working_Users'=$activeWorking;;;; '15_30min_Idle'=$30;$30warn;;; '30_45min_Idle'=$45;$45warn;;; '45min_Plus_Idle'=$45plus;$45pluswarn;;;"
Exit 0