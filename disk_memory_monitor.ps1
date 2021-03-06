$TestArgs = @{}
[String]$TestArgs.TestType = "default"

[String]$TestArgs.DriveLetter = "C:"
[String]$TestArgs.AbsoluteMetric = 0
[int]$TestArgs.ExitCode = 0
[int]$TestArgs.UnkArgCount = 0
[int]$TestArgs.KnownArgCount = 0
[int]$TestArgs.RAMWarn= 90
[int]$TestArgs.RAMCrit = 95
[int]$TestArgs.PageWarn = 75
[int]$TestArgs.PageCrit = 90
[int]$TestArgs.WARN = 90
[int]$TestArgs.CRIT = 97
[string]$TestArgs.Status = ''
[string]$TestArgs.Output = 'NO Test Defined'

Function Process-Args {
    Param ( 
        [Parameter(Mandatory=$True)]$Args,
        [Parameter(Mandatory=$True)]$Return
    )

    For ( $i = 0; $i -lt $Args.count-1; $i++ ) {     
        $CurrentArg = $Args[$i].ToString()
        $Value = $Args[$i+1]
        If (($CurrentArg -imatch "-Test")) {
            If (Check-Strings $Value) {
                $Return.TestType = $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -imatch "-rw") -or ($CurrentArg -match "--RAMWarn")) {
            If (Check-Strings $Value) {
                $Return.RAMWarn = "{0:N2}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -imatch "-rc") -or ($CurrentArg -match "--RAMCrit")) {
            If (Check-Strings $Value) {
                $Return.RAMCrit = "{0:N2}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -imatch "-pw") -or ($CurrentArg -match "--PageWarn")) {
            If (Check-Strings $Value) {
                $Return.PageWarn = "{0:N2}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -imatch "-pc") -or ($CurrentArg -match "--PageCrit")) {
            If (Check-Strings $Value) {
                $Return.PageCrit = "{0:N2}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
        ElseIf (($CurrentArg -imatch "-M") -or ($CurrentArg -match "--Metric")) { 
			$Return.AbsoluteMetric = 1
            $Return.KnownArgCount+=1
		}
		ElseIf (($CurrentArg -imatch "-D") -or ($CurrentArg -match "--Drive")) { 
			$Return.DriveLetter = $value
            $Return.KnownArgCount+=1
		}
		ElseIf (($CurrentArg -imatch "-w") -or ($CurrentArg -match "--Warn")) {
            If (Check-Strings $Value) {
                $Return.WARN = "{0:N2}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
		ElseIf (($CurrentArg -imatch "-c") -or ($CurrentArg -match "--Crit")) {
            If (Check-Strings $Value) {
                $Return.CRIT = "{0:N2}" -f $Value  
				$Return.KnownArgCount+=1
            }
        }
        ElseIf ($CurrentArg -imatch "-debug") { 
            $Return.KnownArgCount+=1
		}						
        ElseIf (($CurrentArg -imatch "-h") -or ($CurrentArg -match "--help")) { 
			$Return.KnownArgCount+=1
			Write-Help
			Exit $Return.ExitCode
		}				
       	else {
			$Return.UnkArgCount+=1
		}
    }		
	$ArgHelp = $Args[0].ToString()	
	if (($ArgHelp -match "--help") -or ($ArgHelp -imatch "-h") ) {
		Write-Help 
		Exit $Return.ExitCode
	}	
	if ($Return.UnkArgCount -ge $Return.KnownArgCount) {
		Write-Host "Unknown: Illegal arguments detected, Please review Help Information"
        Exit $Return.ExitCode
	}
	
Return $Return
}


Function Write-Help {
write-host "
`n This script is designed to monitor Windows RAM and Page File Usage for the local computer.
  
**Required argument is a test type**
	-Test [RAM]|[PageFile]

RAM tests & results are done in GB
Page file tests & results are done in MB

	
Default of Warning and Critical are as follows if none are defined.
--------------------------------------------------------------------------
`nRAM: Warning 90%  `t Critical: 95%
`nPageFile: Warning 75% `t Critical: 90%

Example RAM Test:
`t.\memory_monitor.ps1 -Test RAM
	 
`t.\memory_monitor.ps1 -Test RAM -rw 90 -rc 95
	 


Example Pagefile Test:
`t.\memory_monitor.ps1 -Test PageFile
		 
`t.\memory_monitor.ps1 -Test PageFile -pw 75 -pc 90

	 

`nUsed to define threshold values in an absolute value. 
Default is Percentage.
----------------------------------
      -M 1 = Absolute values are used to define Warning and Critical thresholds (Instead of using Percentages).
    
`nRAM Threshold Settings
----------------------------------
     `t-rw or --RamWarn = Warning threshold for RAM.
     `t-rc or --RamCrit = Critical threshold for RAM.
	 
`nPage File Threshold Settings
----------------------------------
     `t-pw or --PageWarn = Warning threshold for Page File.
     `t-pc or --PageCrit = Critical threshold for Page File.
    
     `n`t-h or --Help => Print this help output.
	 "
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

    
Function Get-Metrics {
	param(
		[Parameter(Mandatory=$True)]$TestArgs
	)
$output =''

    switch ($TestArgs.TestType) {

#RAM Test
    'RAM' {
$RAM = Get-WmiObject -Class Win32_operatingsystem -Property  TotalVisibleMemorySize, FreePhysicalMemory
    $FreePhysicalMemoryRaw = ($RAM.FreePhysicalMemory) / (1mb)
    $TotalVisibleMemorySizeRaw = ($RAM.TotalVisibleMemorySize) / (1mb)
    $TotalVisibleMemorySize = "{0:N2}" -f $TotalVisibleMemorySizeRaw
    $RAMUsedRaw= $TotalVisibleMemorySize - $FreePhysicalMemoryRaw 
    $RAMUsed= "{0:N2}" -f $RAMUsedRaw      
    $TotalFreeMemPercentRaw = ($RAMUsedRaw*100) / $TotalVisibleMemorySizeRaw
    $TotalFreeMemPercent = "{0:N2}" -f $TotalFreeMemPercentRaw

 if($TestArgs.AbsoluteMetric -eq 0) {
         $TestArgs.RamWARN= "{0:N2}" -f ( ($TotalVisibleMemorySizeRaw * $TestArgs.RamWARN ) / 100)
         $TestArgs.RamCRIT= "{0:N2}" -f ( ($TotalVisibleMemorySizeRaw * $TestArgs.RamCRIT ) / 100)
    }

         if ($RAMUsedRaw -lt $TestArgs.RamWARN) { 
         $TestArgs.status ='OK: RAM' 
         $TestArgs.ExitCode = 0
         }  
		if ($RAMUsedRaw -gt $TestArgs.RamWARN) {
             $TestArgs.status = 'WARNING:'
             $TestArgs.ExitCode = 1 
             }
        if ($RAMUsedRaw -gt $TestArgs.RamCRIT) {
             $TestArgs.status = 'CRITICAL:'
             $TestArgs.ExitCode = 2
			 }
        
        $output += "Used: $RAMUsed`GB ($TotalFreeMemPercent%)"
        $output += " [Total RAM: $TotalVisibleMemorySize`GB]"
        $perf_data = "|'Ram_Used'=$RAMUsed`GB;$($TestArgs.RamWARN);$($TestArgs.RamCRIT);0;$TotalVisibleMemorySize 'Total_RAM'=$TotalVisibleMemorySize`GB;0;0;0;$TotalVisibleMemorySize"
        $TestArgs.Output = "$($TestArgs.status) $output $perf_data"
        }
        
#Page Test
    'PageFile' {
$pageFile =  Get-WmiObject -Class Win32_PageFileUsage -Property  AllocatedBaseSize, CurrentUsage, PeakUsage
    $pageFileAllocatedRaw =  ($pageFile).AllocatedBaseSize 
    $pageFileUsedRaw = ($pageFile).CurrentUsage 
    $PageFileMaxRaw = ($pageFile).PeakUsage 
    $pageFileAllocated = "{0:N0}" -f $PageFileAllocatedRaw
    $pageFileUsed = "{0:N0}" -f $pageFileUsedRaw
    $pagefileMax = "{0:N0}" -f $PageFileMaxRaw
       
    if($TestArgs.AbsoluteMetric -eq 0) {
         $TestArgs.PageWARN= ( ($PageFileAllocatedRaw * $TestArgs.PageWARN ) / 100)
         $TestArgs.PageCRIT= ( ($PageFileAllocatedRaw * $TestArgs.PageCRIT ) / 100)    
    }
	
         if ($pageFileUsedRaw -lt $TestArgs.PageWARN) { 
         $TestArgs.status ='OK: Page File' 
         $TestArgs.ExitCode = 0
         }  
		 if ($pageFileUsedRaw -gt $TestArgs.PageWARN) {
             $TestArgs.status = 'WARNING:'
             $TestArgs.ExitCode = 1 
             }
         if ($pageFileUsedRaw -gt $TestArgs.PageCRIT) {
             $TestArgs.status = 'CRITICAL:'
             $TestArgs.ExitCode = 2  
             }
        $output += "Used: $pageFileUsed`MB (Max: $PageFileMax`MB)"
        $output += " Page File Size: [$PageFileAllocated`MB]"
        $perf_data = "|'Total_PageFile'=$PageFileAllocatedRaw`MB;;0;$PageFileAllocatedRaw 'Page_Used'=$PageFileUsedRaw`MB;$($TestArgs.PageWARN);$($TestArgs.PageCRIT);0;$pageFileAllocatedRaw"
        $TestArgs.Output = "$($TestArgs.status) $output $perf_data"
       }
     'Disk' {
		  
		$DiskSpace  = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID=`"$($TestArgs.DriveLetter)`""

		$TotalSpaceRaw = $DiskSpace.Size / (1GB)
		$TotalSpaceGB = "{0:N2}" -f $TotalSpaceRaw

		$FreeSpaceRaw = $DiskSpace.FreeSpace / (1GB)
		$FreeSpaceGB = "{0:N2}" -f $FreeSpaceRaw
		$FreeSpaceMBRaw = $DiskSpace.FreeSpace / (1mb)
		$FreeSpaceMB = "{0:N2}" -f $FreeSpaceMBRaw
		
		$DiskAvail = ($TotalSpaceRaw - $FreeSpaceRaw ) 
		$DiskAvailGB = "{0:N2}" -f $DiskAvail 
		$UsedWARN= "{0:N2}" -f ( ($TotalSpaceRaw * $TestArgs.WARN ) / 100)
		$UsedCRIT= "{0:N2}" -f ( ($TotalSpaceRaw * $TestArgs.CRIT ) / 100)
		$UsedPercent = "{0:N2}" -f ( ($DiskAvail * 100) / $TotalSpaceRaw) 

		$perf_data = "'Disk_Total'=$TotalSpaceGB`GB;;;10;$TotalSpaceGB 'Disk_Used'=$DiskAvailGB`GB;$UsedWARN;$UsedCRIT;10;$TotalSpaceGB"	 

		if($UsedPercent -le $TestArgs.WARN ) {
				$TestArgs.ExitCode = 0
				$TestArgs.Output = "OK: $FreeSpaceGB`GB Available  "
			}
		if ($UsedPercent -gt $TestArgs.WARN) {
				$TestArgs.ExitCode = 1
				$TestArgs.Output = "WARNING: $FreeSpaceGB`GB Available "
			}
		IF ($UsedPercent -ge $TestArgs.CRIT)  {
				$TestArgs.ExitCode = 2
				$TestArgs.Output  = "CRITICAL: ALMOST FULL $FreeSpaceMB`MB Available "
			}

		$TestArgs.Output  += "Used $FreeSpaceGB`GB of $TotalSpaceGB`GB ( $UsedPercent% )"
		$TestArgs.Output = "$($TestArgs.Output)  |$perf_data"

}	 
     default {
     write-host -foreground red 'Test Type not defined!'
	 write-help
        }
    }

}

if($Args.count -ge 1){
	$TestArgs = Process-Args $Args $TestArgs
    get-metrics -TestArgs $TestArgs
    } 
else
{ write-help }

Write-Host $TestArgs.Output
Exit $TestArgs.Exitcode

