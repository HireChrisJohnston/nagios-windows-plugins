# Script name:   	check_ms_windows_disk_load.ps1
# Version:			0.14.10.26
# Created on:    	10/10/2014
# Author:        	D'Haese Willem
# Purpose:       	Check MS Windows disk load by using Powershell to get all disk load related counters from Windows 
#					Performance Manager, computing averages for all gathered samples and calculating read / write rate, 
#					number of reads / writes, read / write latency and read / write queue length.
# On Github:		https://github.com/willemdh/check_ms_win_disk_load
# On OutsideIT:		http://outsideit.net/check_ms_win_disk_load
# Recent History:       	
#	11/10/2014 => Fixed error in outputstring and issue with cookedvalue
#	15/10/2014 => Changes to unit of measurement
#	16/10/2014 => Solved some bugs, implemented warning and critical queue length thresholds
#	17/10/2014 => Documentation and testing
#	26/10/2014 => Fixed bug with exitcode in case OK status.
# Copyright:
#	This program is free software: you can redistribute it and/or modify it under the terms of the
# 	GNU General Public License as published by the Free Software Foundation, either version 3 of 
#   the License, or (at your option) any later version.
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
#	without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
# 	See the GNU General Public License for more details.You should have received a copy of the GNU
#   General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Requires –Version 2.0

[String]$DefaultString = "ABCD123"
[Int]$DefaultInt = -99

$DiskStruct = @{}
	[string]$DiskStruct.Hostname = $DefaultString
	[string]$DiskStruct.DiskLetter = "C"
	[int]$DiskStruct.ExitCode = 3
	[int]$DiskStruct.UnkArgCount = 0
	[int]$DiskStruct.KnownArgCount = 0
	[string]$DiskStruct.OutputString = $DefaultString
	[int]$DiskStruct.MaxSamples = 10
	[int]$DiskStruct.LogicalDiskId = 236
	[int]$DiskStruct.AvgDiskSecReadId = 208
	[int]$DiskStruct.AvgDiskSecReadValue = 0
	[int]$DiskStruct.AvgDiskSecWriteId = 210
	[int]$DiskStruct.AvgDiskSecWriteValue = 0
	[int]$DiskStruct.AvgDiskReadQueueId = 1402
	[int]$DiskStruct.AvgDiskReadQueueValue = 0
	[int]$DiskStruct.AvgDiskWriteQueueId = 1404
	[int]$DiskStruct.AvgDiskWriteQueueValue = 0
	[int]$DiskStruct.DiskReadsSecId = 214
	[int]$DiskStruct.DiskReadsSecValue = 0
	[int]$DiskStruct.DiskWritesSecId = 216
	[int]$DiskStruct.DiskWritesSecValue = 0
	[int]$DiskStruct.DiskReadBytesSecId = 220
	[int]$DiskStruct.DiskReadBytesSecValue = 0
	[int]$DiskStruct.DiskWriteBytesSecId = 222
	[int]$DiskStruct.DiskWriteBytesSecValue = 0	
	[int]$DiskStruct.AvgDiskReadQueueWarn = $DefaultInt
	[int]$DiskStruct.AvgDiskReadQueueCrit = $DefaultInt
	[int]$DiskStruct.AvgDiskWriteQueueWarn = $DefaultInt
	[int]$DiskStruct.AvgDiskWriteQueueCrit = $DefaultInt
	
#region Functions

Function Process-Args {
    Param ( 
        [Parameter(Mandatory=$True)]$Args,
        [Parameter(Mandatory=$True)]$Return
    )

    For ( $i = 0; $i -lt $Args.count-1; $i++ ) {     
        $CurrentArg = $Args[$i].ToString()
        $Value = $Args[$i+1]
        If (($CurrentArg -cmatch "-H") -or ($CurrentArg -match "--Hostname")) {
            If (Check-Strings $Value) {
                $Return.Hostname = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-dl") -or ($CurrentArg -match "--DiskLetter")) {
            If (Check-Strings $Value) {
                $Return.DiskLetter = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-rqw") -or ($CurrentArg -match "--ReadQueueWarn")) {
            If (Check-Strings $Value) {
                $Return.AvgDiskReadQueueWarn = "{0:N5}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-rqc") -or ($CurrentArg -match "--ReadQueueCrit")) {
            If (Check-Strings $Value) {
                $Return.AvgDiskReadQueueCrit = "{0:N5}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-wqw") -or ($CurrentArg -match "--WriteQueueWarn")) {
            If (Check-Strings $Value) {
                $Return.AvgDiskWriteQueueWarn = "{0:N5}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-wqc") -or ($CurrentArg -match "--WriteQueueCrit")) {
            If (Check-Strings $Value) {
                $Return.AvgDiskWriteQueueCrit = "{0:N5}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -cmatch "-ms") -or ($CurrentArg -match "--MaxSamples")) {
            If (Check-Strings $Value) {
                $Return.MaxSamples = $Value  
				$Return.KnownArgCount+=1
            }
        }
        ElseIf (($CurrentArg -cmatch "-h")-or ($CurrentArg -match "--help")) { 
			$Return.KnownArgCount+=1
			Write-Help
			Exit $Return.ExitCode
		}				
       	else {
			$Return.UnkArgCount+=1
		}
    }		
	$ArgHelp = $Args[0].ToString()	
	if (($ArgHelp -match "--help") -or ($ArgHelp -cmatch "-h") ) {
		Write-Help 
		Exit $Return.ExitCode
	}	
	if ($Return.UnkArgCount -ge $Return.KnownArgCount) {
		Write-Host "Unknown: Illegal arguments detected!"
        Exit $Return.ExitCode
	}
	if ($Return.Hostname -eq $DefaultString) {
		$Return.Hostname = ([System.Net.Dns]::GetHostByName((hostname)).HostName).tolower()
	}
    Return $Return
}

Function Check-Strings {
    Param ( [Parameter(Mandatory=$True)][string]$String )
    # `, `n, |, ; are bad, I think we can leave {}, @, and $ at this point.
    $BadChars=@("``", "|", ";", "`n")
    $BadChars | ForEach-Object {
        If ( $String.Contains("$_") ) {
            Write-Host "Unknown: String contains illegal characters."
            Exit $NetStruct.ExitCode
        }
    }
    Return $true
} 

Function Write-Help {
    Write-Host "check_ms_windows_disk_load.ps1:`n`tThis script is designed to monitor Microsoft Windows disk load."
    Write-Host "Arguments:"
    Write-Host "`t-H or --Hostname => Hostname of system."
    Write-Host "`t-dl or --DiskLetter => Hostname of system."	
    Write-Host "`t-rqw or --ReadQueueWarn => Warning threshold for read queue length."
    Write-Host "`t-rqc or --ReadQueueCrit => Critical threshold for read queue length."
	Write-Host "`t-wqw or --WriteQueueWarn => Warning threshold for write queue length."
    Write-Host "`t-wqc or --WriteQueueCrit => Critical threshold for write queue length."
    Write-Host "`t-ms or --MaxSamples => Amount of samples to take."	
    Write-Host "`t-h or --Help => Print this help output."
} 
	
	
function Get-PerformanceCounterID
{
    param
    (
        [Parameter(Mandatory=$true)]
        $Name
    )
 
    if ($script:perfHash -eq $null)
    {
        Write-Progress -Activity 'Retrieving PerfIDs' -Status 'Working'
 
        $key = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\CurrentLanguage'
        $counters = (Get-ItemProperty -Path $key -Name Counter).Counter
        $script:perfHash = @{}
        $all = $counters.Count
 
        for($i = 0; $i -lt $all; $i+=2)
        {
           Write-Progress -Activity 'Retrieving PerfIDs' -Status 'Working' -PercentComplete ($i*100/$all)
           $script:perfHash.$($counters[$i+1]) = $counters[$i]
        }
    }
 
    $script:perfHash.$Name
}

Function Get-PerformanceCounterLocalName
{
  param
  (
    [UInt32]
    $ID,
 
    $ComputerName = $env:COMPUTERNAME
  )
 
  $code = '[DllImport("pdh.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern UInt32 PdhLookupPerfNameByIndex(string szMachineName, uint dwNameIndex, System.Text.StringBuilder szNameBuffer, ref uint pcchNameBufferSize);'
 
  $Buffer = New-Object System.Text.StringBuilder(1024)
  [UInt32]$BufferSize = $Buffer.Capacity
 
  $t = Add-Type -MemberDefinition $code -PassThru -Name PerfCounter -Namespace Utility
  $rv = $t::PdhLookupPerfNameByIndex($ComputerName, $id, $Buffer, [Ref]$BufferSize)
 
  if ($rv -eq 0)
  {
    $Buffer.ToString().Substring(0, $BufferSize-1)
  }
  else
  {
    Throw 'Get-PerformanceCounterLocalName : Unable to retrieve localized name. Check computer name and performance counter ID.'
  }
}

function Get-DiskLoadCounters 
{ 
	param(
		[Parameter(Mandatory=$True)]$DiskStruct
	)
	
	$PerfCounterArray = @()
	
	$LogicalDisk = Get-PerformanceCounterLocalName $DiskStruct.LogicalDiskId
	
	$AvgDiskSecRead = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskSecReadId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskSecRead"
	
	$AvgDiskSecWrite = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskSecWriteId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskSecWrite"
	
	$AvgDiskReadQueue = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskReadQueueId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskReadQueue"	
	
	$AvgDiskWriteQueue = Get-PerformanceCounterLocalName $DiskStruct.AvgDiskWriteQueueId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskWriteQueue"	
	
	$AvgDiskReadsSec = Get-PerformanceCounterLocalName $DiskStruct.DiskReadsSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskReadsSec"	
	
	$AvgDiskWritesSec = Get-PerformanceCounterLocalName $DiskStruct.DiskWritesSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskWritesSec"	
	
	$AvgDiskReadBytesSec = Get-PerformanceCounterLocalName $DiskStruct.DiskReadBytesSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskReadBytesSec"	
	
	$AvgDiskWriteBytesSec = Get-PerformanceCounterLocalName $DiskStruct.DiskWriteBytesSecId
	$PerfCounterArray += "\$LogicalDisk($($DiskStruct.DiskLetter):)\$AvgDiskWriteBytesSec"		
	
	$PfcValues = (Get-Counter $PerfCounterArray -MaxSamples $DiskStruct.MaxSamples)

	$AvgDiskSecReadValues = @()
	$AvgDiskSecWriteValues = @()
	$AvgDiskReadQueueValues = @()
	$AvgDiskWriteQueueValues = @()
	$AvgDiskReadsSecValues = @()
	$AvgDiskWritesSecValues = @()
	$AvgDiskReadBytesSecValues = @()
	$AvgDiskWriteBytesSecValues = @()
		
	for ($y=0; $y -lt $DiskStruct.MaxSamples; $y++) {			
		$AvgDiskSecReadValues += $PfcValues[$y].CounterSamples[0].CookedValue		
		$AvgDiskSecWriteValues += $PfcValues[$y].CounterSamples[1].CookedValue	
		$AvgDiskReadQueueValues += $PfcValues[$y].CounterSamples[2].CookedValue
		$AvgDiskWriteQueueValues += $PfcValues[$y].CounterSamples[3].CookedValue
		$AvgDiskReadsSecValues += $PfcValues[$y].CounterSamples[4].CookedValue
		$AvgDiskWritesSecValues += $PfcValues[$y].CounterSamples[5].CookedValue
		$AvgDiskReadBytesSecValues += $PfcValues[$y].CounterSamples[6].CookedValue
		$AvgDiskWriteBytesSecValues += $PfcValues[$y].CounterSamples[7].CookedValue	
	}
	
	$AvgObjDiskSecReadValues = $AvgDiskSecReadValues | Measure-Object -Average
	$AvgObjDiskSecWriteValues = $AvgDiskSecWriteValues | Measure-Object -Average
	$AvgObjDiskReadQueueValues = $AvgDiskReadQueueValues | Measure-Object -Average
	$AvgObjDiskWriteQueueValues = $AvgDiskWriteQueueValues | Measure-Object -Average
	$AvgObjDiskReadsSecValues = $AvgDiskReadsSecValues | Measure-Object -Average
	$AvgObjDiskWritesSecValues = $AvgDiskWritesSecValues | Measure-Object -Average
	$AvgObjDiskReadBytesSecValues = $AvgDiskReadBytesSecValues | Measure-Object -Average
	$AvgObjDiskWriteBytesSecValues = $AvgDiskWriteBytesSecValues  | Measure-Object -Average
	
	$DiskStruct.AvgDiskSecReadValue = "{0:N5}" -f ($AvgObjDiskSecReadValues.Average * 1000)
	$DiskStruct.AvgDiskSecWriteValue = "{0:N5}" -f ($AvgObjDiskSecWriteValues.average * 1000)
	$DiskStruct.AvgDiskReadQueueValue = "{0:N5}" -f ($AvgObjDiskReadQueueValues.average)
	$DiskStruct.AvgDiskWriteQueueValue = "{0:N5}" -f ($AvgObjDiskWriteQueueValues.average)
	$DiskStruct.AvgDiskReadsSecValue = "{0:N5}" -f ($AvgObjDiskReadsSecValues.average)
	$DiskStruct.AvgDiskWritesSecValue = "{0:N5}" -f ($AvgObjDiskWritesSecValues.average)
	$DiskStruct.AvgDiskReadBytesSecValue = "{0:N5}" -f ($AvgObjDiskReadBytesSecValues.average / 1024 / 1024)
	$DiskStruct.AvgDiskWriteBytesSecValue = "{0:N5}" -f ($AvgObjDiskWriteBytesSecValues.average / 1024 / 1024)

	$ReadQueueCritThreshReached = $false
	$ReadQueueWarnThreshReached = $false
	$WriteQueueCritThreshReached = $false
	$WriteQueueWarnThreshReached = $false

	if ($DiskStruct.AvgDiskReadQueueCrit -ne $DefaultInt -and $DiskStruct.AvgDiskReadQueueValue -gt $DiskStruct.AvgDiskReadQueueCrit) {
		$DiskStruct.ExitCode = 2
		$ReadQueueCritThreshReached = $true
		$OutputReadQueue = "CRITICAL: Read Queue Threshold ($($DiskStruct.AvgDiskReadQueueCrit)) Passed!"
	}
	elseif ($DiskStruct.AvgDiskReadQueueWarn -ne $DefaultInt -and $DiskStruct.AvgDiskReadQueueValue -gt $DiskStruct.AvgDiskReadQueueWarn) {
		$DiskStruct.ExitCode = 1
		$ReadQueueWarnThreshReached = $true
		$OutputReadQueue = "WARNING: Read Queue Threshold ($($DiskStruct.AvgDiskReadQueueWarn)) Passed!"
	}
	if ($DiskStruct.AvgDiskWriteQueueCrit -ne $DefaultInt -and $DiskStruct.AvgDiskWriteQueueValue -gt $DiskStruct.AvgDiskWriteQueueCrit) {
		$DiskStruct.ExitCode = 2
		$WriteQueueCritThreshReached = $true
		$OutputWriteQueue = "CRITICAL: Write Queue Threshold ($($DiskStruct.AvgDiskWriteQueueCrit)) Passed!"
	}
	elseif ($DiskStruct.AvgDiskWriteQueueWarn -ne $DefaultInt -and $DiskStruct.AvgDiskWriteQueueValue -gt $DiskStruct.AvgDiskWriteQueueWarn) {
		$DiskStruct.ExitCode = 1
		$WriteQueueWarnThreshReached = $true
		$OutputWriteQueue = "WARNING: Write Queue Threshold ($($DiskStruct.AvgDiskWriteQueueWarn)) Passed!"
	}
									
	if ($ReadQueueCritThreshReached -eq $false -and $ReadQueueWarnThreshReached -eq $false -and $WriteQueueCritThreshReached -eq $false -and $WriteQueueWarnThreshReached -eq $false) {	
		$DiskStruct.OutputString = "OK: Drive $($DiskStruct.DiskLetter): Avg of $($DiskStruct.MaxSamples) samples: {Rate (Read: $($DiskStruct.AvgDiskReadBytesSecValue)MB/s)(Write: $($DiskStruct.AvgDiskWriteBytesSecValue)MB/s)} {Avg Nr of (Reads: $($DiskStruct.AvgDiskReadsSecValue)r/s)(Writes: $($DiskStruct.AvgDiskReadsSecValue)w/s)} {Latency (Read: $($DiskStruct.AvgDiskSecReadValue)us)(Write: $($DiskStruct.AvgDiskSecWriteValue)us)} {Queue Length (Read: $($DiskStruct.AvgDiskReadQueueValue)ql)(Write: $($DiskStruct.AvgDiskReadQueueValue)ql)} | "
		$DiskStruct.ExitCode = 0
	}
	else {
		$DiskStruct.OutputString = "$OutputReadQueue $OutputWriteQueue : Drive $($DiskStruct.DiskLetter): Avg of $($DiskStruct.MaxSamples) samples: {Rate (Read: $($DiskStruct.AvgDiskReadBytesSecValue)MB/s)(Write: $($DiskStruct.AvgDiskWriteBytesSecValue)MB/s)} {Avg Nr of (Reads: $($DiskStruct.AvgDiskReadsSecValue)r/s)(Writes: $($DiskStruct.AvgDiskReadsSecValue)w/s)} {Latency (Read: $($DiskStruct.AvgDiskSecReadValue)us)(Write: $($DiskStruct.AvgDiskSecWriteValue)us)} {Queue Length (Read: $($DiskStruct.AvgDiskReadQueueValue)ql)(Write: $($DiskStruct.AvgDiskWriteQueueValue)ql)} | "
	}
	
	$DiskStruct.OutputString += "'Read_Latency'=$($DiskStruct.AvgDiskSecReadValue)us "
	$DiskStruct.OutputString += "'Write_Latency'=$($DiskStruct.AvgDiskSecWriteValue)us "
	$DiskStruct.OutputString += "'Read_Queue'=$($DiskStruct.AvgDiskReadQueueValue)ql "
	$DiskStruct.OutputString += "'Write_Queue'=$($DiskStruct.AvgDiskWriteQueueValue)ql "
	$DiskStruct.OutputString += "'Nnumber_of_Reads'=$($DiskStruct.AvgDiskReadsSecValue)r/s "
	$DiskStruct.OutputString += "'Number_of_Writes'=$($DiskStruct.AvgDiskWritesSecValue)w/s "
	$DiskStruct.OutputString += "'Read_Rate'=$($DiskStruct.AvgDiskReadBytesSecValue)MB/s "
	$DiskStruct.OutputString += "'Write_Rate'=$($DiskStruct.AvgDiskWriteBytesSecValue)MB/s "	
}

#endregion

# Main function 
if($Args.count -ge 1){
	$DiskStruct = Process-Args $Args $DiskStruct
}
if ($DiskStruct.Hostname -eq $DefaultString) {
	$DiskStruct.Hostname = ([System.Net.Dns]::GetHostByName((hostname)).HostName).tolower()
}

Get-DiskLoadCounters -DiskStruct $DiskStruct

Write-Host $DiskStruct.OutputString

Exit $DiskStruct.ExitCode