# nagios-windows-plugins
Nagios Windows service and host plugins which include performance data for charts and capacity planning

# check_host.ps1

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

# check_win_cpu.ps1
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

