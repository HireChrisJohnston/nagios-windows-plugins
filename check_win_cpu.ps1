<#
.SYNOPSIS 
	Nagios check plugin used for monitoring CPU usage sampling CPU Average, User Time, Privileged, Interrupt, DPC, CPU Queue,
	and Max CPU usage during the sample period. Output includes nagios performance data for charting and alerts
	
.DESCRIPTION 
	CPU usage is calculated using a number of intervals and sleep period between intervals to get the desired flexibility for
	calculating total CPU usage. Most nagios performance checks lack the ability to be more true to CPU usage because 
	a single sample at one moment in time is insufficient information. By default the plugin was designed with speed in mind
	so that the nagios plugin would not take too long to retrun a result, this can in turn allow you to increase the freshness
	requirement in the nagios configuration for a fine tuned time vs. freshness mix creating accurate and reactive nagiog alerts.
	
	This Nagios Plugin takes 60 (default) samples of the CPU metrics and sleeps 0.7 seconds (default) between each sample to calculate an average CPU usage, over a configurable amount of time.
	
	Performance data is output by default.
	Thresholds have default 'nominal' values and requires no command line arguments to run the check.
	
    File Name  : checek_cpu.ps1 
    Author     : Chris Johnston - HireChrisJohnston@gmail.com
    Requires   : PowerShell V2
	License	   : MIT
    
	Alerts occur based on performance data for Privileges and Total Processor Time
	Includes charting the Maximum CPU samples observed over the collection of samples
	to further enhance and provide detail to CPU utilization.
	
	Usage is calculated across all cores for total CPU usage.  Adjust the variables as needed for changing the sampling method
	or thresholds from the default via command line
	
		-delay 		(default 0.7) Sleep time between reps
		-reps 		(default 60) Number of samples to take
		-privwarn 	(default 50) Privileged CPU warning threshold
		-privcrit 	(default 75) Privileged CPU critical threshold
		-cpuwarn 	(default 80.3) CPU Average warning threshold
		-cpucrit 	(default 95) CPU Average critical threshold
		
	Nagios Performance data example seen below and has been formatted for readability of the performance metrics.

.EXAMPLE 
	PS C:\foo> .\check_win_cpu.ps1 -delay 1 -reps 5 -privwarn 50  -privcrit 75 -cpuwarn 80.3 -cpucrit 95
	
	OK: CPU - 5 sample average: 1.20% (Max:2% - Max Queue:0)|
	'Max_CPU'=2%;;;0;100
	'CPU_Average'=1.20%;80.3;95;0;100
	'User_Time'=0.20%;;;0;100
	'Privileged'=0.00%;50;75;0;100
	'Interrupt'=0.00%;50;70;0;100
	'DPC_Time'=0.00%;50;75;0;100
	'Max_Queue'=0;18;32;0;50

.LINK
	https://github.com/HireChrisJohnston/nagios-windows-plugins

#>
param (
	# Sleep for x between reps
    [float]$delay = '0.7', 
	# Number of CPU usage samples to take for calculating CPU
    [float]$reps = '60',
    [float]$cpuWARN='80.3',
    [float]$cpuCRIT='95',
	[float]$PrivWARN='50',
	[float]$PrivCRIT='75'
)

$propertyUser = "PercentUserTime"
$propertyPercent = "PercentProcessorTime"
$propertyDPC = "PercentDPCTime"
$propertyInterrupt = "PercentInterruptTime"
$propertyPriviledge = "PercentPrivilegedTime"
$status = 'OK'
$detail =''

Function CreateEmptyArray($ubound)
{
 [int[]]$script:CPU = [array]::CreateInstance("int",$ubound)
 [int[]]$script:User = [array]::CreateInstance("int",$ubound)
 [int[]]$script:DPC = [array]::CreateInstance("int",$ubound)
 [int[]]$script:Interrupt = [array]::CreateInstance("int",$ubound)
 [int[]]$script:Priviledge = [array]::CreateInstance("int",$ubound)
 [int[]]$script:Queue = [array]::CreateInstance("int",$ubound)
} # CreateEmptyArray
Function GetWmiPerformanceData()
{
 For($i = 0 ; $i -le $reps -1 ; $i++)
  {
  $data_proc = get-wmiobject Win32_PerfFormattedData_PerfOS_Processor -filter 'Name="_Total"'
  $data_system = get-wmiobject  Win32_PerfFormattedData_PerfOS_System 
   $CPU[$i] +=($data_proc).$PropertyPercent
   $User[$i] +=($data_proc).$PropertyUser
   $DPC[$i] +=($data_proc).$PropertyDPC
   $Interrupt[$i] +=($data_proc).$PropertyInterrupt
   $Priviledge[$i] +=($data_proc).$PropertyPriviledge
  $Queue[$i] +=($data_system).ProcessorQueueLength
   Start-Sleep -Seconds $delay
  } #end for
}#end GetWmiPerformanceData

Function EvaluateCPU()
{ $CPU | Measure-Object -Average -Maximum -Minimum}

Function EvaluateUser()
{ $User | Measure-Object -Average -Maximum -Minimum}

Function EvaluateDPC()
{ $DPC | Measure-Object -Average -Maximum -Minimum}

Function EvaluateInterrupt()
{ $Interrupt | Measure-Object -Average -Maximum -Minimum}

Function EvaluatePriviledge()
{ $Priviledge | Measure-Object -Average -Maximum -Minimum } 

Function EvaluateQueue()
{ $Queue | Measure-Object -Average -Maximum -Minimum } 

#End EvaluateObject

CreateEmptyArray($reps)
GetWmiPerformanceData

$CPUResult = EvaluateCPU
$maxCPU = ($CPUResult).Maximum
$avgCPU = "{0:N2}" -f ($CPUResult).Average

$UserResult = EvaluateUser
$maxCPUUser = ($UserResult).Maximum
$avgCPUUser = "{0:N2}" -f ($UserResult).Average

$DPCResult = EvaluateDPC
$maxDPC = ($DPCResult).Maximum
$avgDPC = "{0:N2}" -f ($DPCResult).Average

$InterruptResult = EvaluateInterrupt
$maxInterrupt = ($InterruptResult).Maximum
$avgInterrupt = "{0:N2}" -f ($InterruptResult).Average

$PriviledgeResult = EvaluatePriviledge
$maxPriviledge = ($PriviledgeResult).Maximum
$avgPriviledge = "{0:N2}" -f ($PriviledgeResult).Average

$QueueResult = EvaluateQueue
$maxQueue = ($QueueResult).Maximum
$avgQueue = "{0:N0}" -f ($QueueResult).Average

$perfdata = "'Max_CPU'=$maxCPU%;;;0;100"
$perfdata += " 'CPU_Average'=$avgCPU%;$cpuWARN;$cpuCRIT;0;100"
$perfdata += " 'User_Time'=$avgCPUUser%;;;0;100"
$perfdata += " 'Privileged'=$avgPriviledge%;$PrivWARN;$PrivCRIT;0;100"
$perfdata += " 'Interrupt'=$avgInterrupt%;50;70;0;100"
$perfdata += " 'DPC_Time'=$avgDPC%;50;75;0;100"
$perfdata += " 'Max_Queue'=$maxQueue;18;32;0;50"

 
if($avgCPU -ge $cpuWARN) { 
	$status='WARNING' ; $detail +='CPU Is High '; $exitcode=1
	} else {
	$exitcode=0
	}
if($avgCPU -ge $cpuCRIT) { $status='CRITICAL' ; $detail +='CPU Is Very Busy ' ; $exitcode=2}

if($avgPriviledge -ge $PrivWARN ) { $status='WARNING' ; $detail +='-Kernel Time Is High '}
if($avgPriviledge -ge $PrivCRIT) { $status='CRITICAL' ; $detail +='-Kernel Time Is Too High '}

if($detail) { $detail = " [$detail]"}

write-host "$status`:$detail CPU - $reps sample average: $avgCPU% (Max:$maxCPU% - Max Queue:$maxQueue)|$perfdata"
Exit $exitcode
