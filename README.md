# nagios-windows-plugins
Nagios Windows service and host plugins which include performance data for charts and capacity planning

# [check_host.ps1](check_host.ps1)

## DESCRIPTION 
No options exist and the plugin is used for monitoring Windows Servers running RDS. Performance data is output by default. Nagios
check plugin used for host monitoring of Remote Desktop Services (RDS) including uptime and CPU usage for Nagios performance charts
for total CPU.

No alerts occur based on performance data but instead are based on the Windows RDS service in a "Running" state.
Usage is calculated across all cores for total CPU usage.

Nagios Performance data example seen below and has been formatted for readability of the performance metrics.

### Example
PS C:\foo> .\check_host.ps1
	
	CRITICAL: Remote Desktop Service is not running - Up for 7 Days 21 Hours 27 Minutes
	|'%ProcessorTime'=1.69% 
	'%UserTime'=0.78% 
	'%PrivilegedTime'=0.20% 
	'%InterruptTime'=0.00% 
	'%DPCTime'=0.00%
---

# [check_win_cpu.ps1](check_win_cpu.ps1)
Nagios check plugin used for monitoring CPU usage sampling CPU Average, User Time, Privileged, Interrupt, DPC, CPU Queue,
and Max CPU usage during the sample period. Output includes nagios performance data for charting and alerts
	
## DESCRIPTION 
CPU usage is calculated using a number of intervals and sleep period between intervals to get the desired flexibility for
calculating total CPU usage. Most nagios performance checks lack the ability to be more true to CPU usage because 
a single sample at one moment in time is insufficient information. By default the plugin was designed with speed in mind
so that the nagios plugin would not take too long to retrun a result, this can in turn allow you to increase the freshness
requirement in the nagios configuration for a fine tuned time vs. freshness mix creating accurate and reactive nagiog alerts.
	
This Nagios Plugin takes 60 (default) samples of the CPU metrics and sleeps 0.7 seconds (default) between each sample to calculate an average CPU usage, over a configurable amount of time.
	
Performance data is output by default.
Thresholds have default 'nominal' values and requires no command line arguments to run the check.
    
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

### EXAMPLE 
PS C:\foo> .\check_win_cpu.ps1 -delay 1 -reps 5 -privwarn 50  -privcrit 75 -cpuwarn 80.3 -cpucrit 95
	
	OK: CPU - 5 sample average: 1.20% (Max:2% - Max Queue:0)|
	'Max_CPU'=2%;;;0;100
	'CPU_Average'=1.20%;80.3;95;0;100
	'User_Time'=0.20%;;;0;100
	'Privileged'=0.00%;50;75;0;100
	'Interrupt'=0.00%;50;70;0;100
	'DPC_Time'=0.00%;50;75;0;100
	'Max_Queue'=0;18;32;0;50

---

# [check_user_session_activity.ps1](check_user_session_activity.ps1)

## Description

Nagios check plugin used for monitoring user counts and group them by activity of active (5min or less), 15min, 30min, 45min and 45+min idle users.
* Output includes Nagios performance data for charting.
* Performance data is output by default.
* No alerts occur with the plugin at this time. 

It is used for performance charting and informational only.
Perfect for layering in Nagios XI Graph Explorer

Grouping of users by their idle status from Windows RDS (Remote Desktop Server) 
which has a maximum inactivity value of 1 minute before being considered idle:

* Working Users(Active) = Less than 4 min idle or in active status reported by RDS
* 15min = 5-15min idle
* 30min	= 16-30min idle
* 45min = 31-45min idle
* 45plus = more than 46min idle

## Requires
Remote Desktop Services to count the active users and group them by idle time.

Outputs HTML so you must enable that Nagios option

### Nagios XI
Admin -> System Settings and check the "Allow HTML Tags in Host/Service Status" 

### Nagios
Set `escape_html_tags=0` in your cgi.cfg

	
## Example 

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

---

# [check_process.ps1 ](check_process.ps1 )
Checks for a running process, if not running it will retun as a WARNING alert for Nagios

## Description
    
Specify the process using regular expressions knowing it uses where 'like' matching
using the commandline switch. Even though the return code to Nagios will result as a WARNING, 
the text output of the plugin indicates critical for cohersion of the operators to take action.

Use regular expressions for the -process command line option.

PS C:\> .\check_process.ps1 -process `'*notepad*'`
	
	OK: Process Running contining *notepad* in the commandline

PS C:\> .\check_process.ps1 -process '*notepad'

	CRITICAL: Process containing (*notepad) in the commandline is not running
