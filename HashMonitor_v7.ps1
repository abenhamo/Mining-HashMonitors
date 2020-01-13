
$ver = "0.2"
$Host.UI.RawUI.WindowTitle = "Vega Cryptonight HashMonitor v $ver"
$Host.UI.RawUI.BackgroundColor = "Black"

Clear-Host

Push-Location $PSScriptRoot

###################################################
################## UserVeriables ##################
###################################################

#all commands to run the programs are found in this section.

$logFile = "LOGS/VEGA_monitor_$(get-date -f yyyy-MM-dd).log"	#if you do not want a log file comment this out. (Add # to the begining of the line)
$IP = '127.0.0.1'	#IP address of Cast-xmr.  Usually 127.0.0.1 for local machine.
$Port = '7777'		#port of cast-xmr.  Default 7777
$checkPeriod = 60		#how often to check cast-xmr in seconds,
$maxFail = 3			#how many times the hash rate can be under a set vaule before restart
$roundedRestartHashRate = 5000 	# 1600 * number of cards , around 250 H/s Loss per card
$sleepBeforeCheck = 40	#number of seconds to wait before trying to connect to stak. 10s * cards number

#command to start overdrive.  Overdrive should be in the same folder to start. Comment out if you do not want to use overdriveNTool
$overdriveStart = "overdriventool.exe -r1 -r2 -r3 -r4 -r5 -r6 -r7 -r8 -p1vegan -p2vegan -p3vegan -p4vegan -p5vegan -p6vegan -p7vegan -p8vegan" #Adjust "overdriventool.exe -p1MINING1" to "-p1(Your OverdriveNTool config name)"

#command to start cast.  Cast must be in the same folder to start. (Make sure to change the wallet address to your own, it's the long string of text just after the -u Also, specify how many cards you are using after the -G (0,1,2,etc to number of cards you are using). -R is needed for monitoring)
$castStart = "cast_xmr-vega.exe --algo=1 --fastjobswitch --remoteaccess -G 0,1,2,3,4,5,6,7 -S stratum.hashmania.fr:8887 -u Rig4 -p x %*"
$stakStart = "xmr-stak.exe --noCPU --noNVIDIA"
$useStak = $false #set to false to use Cast
$preHashMonitor = "preHashMonitor.ps1"



###################################################
############### End of UserVeriables ##############
######### MAKE NO CHANGES BELOW THIS LINE #########
###################################################


$global:runDays = $null
$global:runHours = $null
$global:runMinutes = $null
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$scriptName = $MyInvocation.MyCommand.Name
$restartHashRate = $roundedRestartHashRate *1000
if($useStak)
{
$global:Url = "http://$IP`:$Port/api.json"
}
else
{
$global:Url = "http://$IP`:$Port"
}


########BEGIN FUNCTIONS########
#Test for Admin
function Force-Admin {
	Param(
	[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
	[System.Management.Automation.InvocationInfo]$MyInvocation)
	
	#Get current ID and security principal
	$windowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($windowsID)
	
	#Get the admin role security principal
	$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
	
	#are we in an admin role?
	if (-NOT ($windowsPrincipal.IsInRole($adminRole))) {
		#get the script path
		$scriptPath = $MyInvocation.MyCommand.Path
		$scriptPath = Get-UNCFromPath -Path $scriptPath
		
		#need to quote the paths in case of spaces
		$scriptPath = '"' + $scriptPath + '"'
		
		#build base arguments for powershell.exe
		[string[]]$argList = @('-NoLogo -NoProfile', '-ExecutionPolicy Bypass', '-File', $scriptPath)
		
		#add 
		$argList += $MyInvocation.BoundParameters.GetEnumerator() | Foreach {"-$($_.Key)", "$($_.Value)"}
		$argList += $MyInvocation.UnboundArguments
		
		try
		{    
			$process = Start-Process PowerShell.exe -PassThru -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList
			exit $process.ExitCode
		}
		catch {}
		
		# Generic failure code
		exit 1
	} #if (-NOT ($windowsPrincipal.IsInRole($adminRole)))
} #function Force-Admin

function Log-Write {
	Param ([string]$logstring)
	If ($Logfile)
	{
		Add-content $Logfile -value $logstring
	}
}

function Resize-Console
{


$host.UI.RawUI.WindowSize = New-Object -TypeName System.Management.Automation.Host.Size -ArgumentList (78, 38)
}


function restart_GPU {
	###################################
	##### Reset Video Card(s) #####
	##### No error checking
	Write-host "Resetting Video Card(s)..."
	$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	log-Write ("$timeStamp	Running Video Card Reset")
	$d = Get-PnpDevice| where {$_.friendlyname -like 'Radeon RX Vega'}
	$vCTR = 0
	foreach ($dev in $d) {
		$vCTR = $vCTR + 1
		Write-host -fore Green "Disabling "$dev.Name '#'$vCTR
		Disable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false | Out-Null
		$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		log-Write ("$timeStamp	Disabled $vCTR $dev")
		Start-Sleep -s 1
		Write-host -fore Green "Enabling "$dev.Name '#' $vCTR
		Enable-PnpDevice -DeviceId $dev.DeviceID -ErrorAction Ignore -Confirm:$false | Out-Null
		$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		log-Write ("$timeStamp	Enabled $vCTR $dev")
		#Start-Sleep -s 1
	}
	$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	log-Write ("$timeStamp	$vCTR Video Card(s) Reset")
	Write-host -fore Green $vCTR "Video Card(s) Reset"
}

function Run-Overdrive {

    foreach ($item in $overdriveStart)
	{
		$prog = ($item -split "\s", 2)
		if (Test-Path $prog[0])
		{	
		    $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		    Log-Write("$timeStamp Starting $overdriveStart")
		    Write-Host -fore Green "`nStarting $overdriveStart."
			If ($prog[1]) {
				Start-Process -FilePath $prog[0] -ArgumentList $prog[1] | Out-Null
			}
			Else
			{
			Start-Process -FilePath $prog[0] | Out-Null
			}
        $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		Log-Write("$timeStamp $overdriveStart started")
		Write-Host -fore Green "`n$overdriveStart started."
		}
		Else
		{
		$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		Log-Write("$timeStamp $prog[0] not found. Not critical. continuing")
		Write-Host -fore Red "`n$prog[0] not found. Not critical. continuing"
		}
	}
   
}

function Start-Mining {

    if ($useStak) { 
        $miner = $stakStart
    }
    else {
        $miner = $castStart
    }
    $minerExe = $miner.split(" ")[0]
    $minerArg = $miner.split(" ")
    $minerArgString = [system.String]::Join(" ",$minerArg[1..$minerArg.Length])
	$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	log-Write ("$timeStamp	Starting $minerExe ...")
	If (Test-Path $minerExe)
	{ 
		Write-Host "Starting $minerExe..."
		If ($minerArgString)
		{
			Start-Process -FilePath $ScriptDir\$minerExe -ArgumentList $minerArgString -WindowStyle Minimized
		}
		Else
		{
			Start-Process -FilePath $ScriptDir\$minerExe
		}
	}
	Else
	{
		$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		log-Write ("$timeStamp	$minerExe NOT FOUND.. EXITING")
		Clear-Host
		Write-Host -fore Red `n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		Write-Host -fore Red "         $minerExe NOT found. "
        Write-Host -fore Red "   Can't do much without the miner now can you!"
		Write-Host -fore Red "          Now exploding... buh bye!"
		Write-Host -fore Red !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		Write-Host -NoNewLine "Press any key to continue..."
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit
	}
}

function get-RunTime ($sec)
{
	$myTimeSpan = (new-timespan -seconds $sec)
	If ($sec -ge 3600 -And $sec -lt 86400)
	{ 
		$global:runHours = $myTimeSpan.Hours
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runHours Hours $global:runMinutes Min"
	}
	ElseIf ($sec -ge 86400)
	{
		$global:runDays = $myTimeSpan.Days
		$global:runHours = $myTimeSpan.Hours
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runDays Days $global:runHours Hours $global:runMinutes Min"
	}
	Elseif ($sec -ge 60 -And $sec -lt 3600)
	{
		$global:runMinutes = $myTimeSpan.Minutes
		Return "$global:runMinutes Min"
	}
	Elseif ($sec -lt 60)
	{
		Return "Less than 1 minute"
	}
}


function set-ENVVars
{
	Write-host -fore Yellow "Setting Env Variables"
	$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	log-Write ("$timeStamp	Setting Env Variables")

	[System.Environment]::SetEnvironmentVariable("GPU_FORCE_64BIT_PTR", "1")
	[System.Environment]::SetEnvironmentVariable("GPU_MAX_HEAP_SIZE", "100")
	[System.Environment]::SetEnvironmentVariable("GPU_MAX_ALLOC_PERCENT", "100")
	[System.Environment]::SetEnvironmentVariable("GPU_SINGLE_ALLOC_PERCENT", "100")
    
    


	
	Write-host -fore Green "Env Variables have been set"
	$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	log-Write ("$timeStamp	Env Variables have been set")
}

function Check-HashRate {
	if ($useStak) {
        #checks the current hash rate against $restartHashRate every $checkPeriod
	    Clear-Host
        $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	    Write-Host -fore Yellow "`n$timeStamp  Hash monitoring has begun."
	    Log-Write("$timeStamp Hash monitoring has begun")
	    $attempt = 0
	    $reason = ""
	    $previousRateTot = 0
	
	    DO {
       
		    #sleep before checking
		    Start-Sleep -s $checkPeriod
		    $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		    Write-Host -fore Green "`n$timeStamp Querying Stak-xmr...this can take a minute"
		    $rawData = Invoke-WebRequest -UseBasicParsing -Uri $global:Url -TimeoutSec 60
            Clear-Host
            $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
      
		    if ($rawData -eq $null){
			    #if there is no data then the http request failed.
			    $attempt = $attempt + 1
			    $reason = "http request failed"
			    Log-Write("$timeStamp Failed to connect to website")
                Write-Host -fore Red "$timeStamp Failed to connect to website"
		    } else {
			    #extract data and write to log files.
			    $data = $rawData |ConvertFrom-Json
                $hashRateTot =  $data.hashrate.total[0]
			    $sharesAccepted = $data.results.shares_good
                $sharesTotal = $data.results.shares_total
			    $sharesRejected = $sharesTotal-$sharesAccepted
			   
                $online =$data.connection.uptime
                $server = $data.connection.pool
                $diff = $data.results.diff_current
                $runtime = get-RunTime($online)
			    $goodShares = [math]::Round(($sharesAccepted / $sharesTotal * 100),2)
                $poolData = "`nPool Running Time : $runtime`nPool server: $server`nPool difficulty: $diff"
			    $sharesData = "`nTotal HashRate: $hashRateTot H/s`nAccepted Shares: $sharesAccepted`nRejected Shares: $sharesRejected`nGood Shares: $goodShares %"
                #Log-Write("$writedata")
                Write-Host -fore Cyan "`n$timeStamp"
                Write-Host -fore Yellow "`nRestarting HashRate Threshold = $roundedRestartHashRate H/s" 
                Write-Host -fore Gray "`n==========================Pool Data==========================`n$poolData"
                Write-Host -fore DarkCyan  "`n=========================Shares Data=========================`n$sharesdata"
                Write-Host -fore DarkGray "`n==========================GPUs Data=========================="
			    for ($i=0; $i -lt $data.hashrate.threads.Length; $i++) {
				    $thread = $data.hashrate.threads[$i]
				    $hashRate = $thread[0]
				    $writedata = "Thread[$i] HashRate: $hashRate H/s"
                    Write-Host -fore DarkGray "$writedata"
			    } #for ($i=0; $i -lt $data.devices.Length; $i++)
			     Write-Host -fore Gray "`n==========================Status============================="
			    #check if hashRate has changed.
			    if ($hashRateTot -eq $previousRateTot) {
				    $attempt = $attempt +1
				    $reason = "HashRate hasn't changed.  Cast may be fozen"
				    Log-Write("$timeStamp $reason")
				    Write-Host -fore Red "`n$reason"
                } else {
                    #check if hashRate has dropped.
			        if ($hashRateTot -lt $roundedRestartHashRate) {
				        $attempt = $attempt +1
				        $reason = "HashRate is below expected value."
				        Log-Write("$timeStamp $reason")
                        Log-Write("      HashRate = $hashrateTot H/s.   expected value = $roundedRestartHashRate H/s")
	    			    Write-Host -fore Red "`n$reason"
                        Write-Host -fore Red "`n       HashRate = $hashrateTot H/s.   expected value = $roundedRestartHashRate H/s"
			        } else {
				        $attempt = 0
					    Write-Host -fore Green "`nHash Rate OK. HashRate = $hashrateTot H/s"
				    } # else ($hashRateTot -lt $restartHashRate)
			    } # else ($hashRateTot -eq $previousRateTot)
            
                #update previous hashRateTotal
                $previousRateTot = $hashRateTot

		    } #	else ($rawData -eq $null)
        
	    } while ($attempt -lt $maxFail)

	    $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	    Write-Host -fore Red "`n$timeStamp $reason restarting in 10 seconds"
	    Log-Write("$timeStamp $reason.  Restarting script in 10 seconds")

    }
    else {
	    #checks the current hash rate against $restartHashRate every $checkPeriod
	    Clear-Host
        $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	    Write-Host -fore Yellow "`n$timeStamp  Hash monitoring has begun."
	    Log-Write("$timeStamp Hash monitoring has begun")
	    $attempt = 0
	    $reason = ""
	    $previousRateTot = 0
	
	    DO {
       
		    #sleep before checking
		    Start-Sleep -s $checkPeriod
		    $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
		    Write-Host -fore Green "`n$timeStamp Querying Cast-Xmr...this can take a minute"
		    $rawData = Invoke-WebRequest -UseBasicParsing -Uri $global:Url -TimeoutSec 60
            Clear-Host
            $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
      
		    if ($rawData -eq $null){
			    #if there is no data then the http request failed.
			    $attempt = $attempt + 1
			    $reason = "http request failed"
			    Log-Write("$timeStamp Failed to connect to website")
                Write-Host -fore Red "$timeStamp Failed to connect to website"
		    } else {
			    #extract data and write to log files.
			    $data = $rawData |ConvertFrom-Json
                $hashRateTot =  $data.total_hash_rate
			    $roundedHashRateTot = [math]::Round($hashRateTot/1000,2)
                $avgTot = $data.total_hash_rate_avg
			    $roundedAvgTot = [math]::Round($avgTot/1000,2)  
			    $sharesAccepted = $data.shares.num_accepted
			    $sharesRejected = $data.shares.num_rejected
			    $sharesInvalid = $data.shares.num_invalid
                $sharesOutdated = $data.shares.num_outdated
                $online =$data.pool.online
                $server = $data.pool.server
                $diff = $data.job.difficulty
                $runtime = get-RunTime($online)
			    $goodShares = [math]::Round(($sharesAccepted / ($sharesInvalid+$sharesRejected+$sharesAccepted+$sharesOutdated) * 100),2)
                $poolData = "`nPool Running Time : $runtime`nPool server: $server`nPool difficulty: $diff"
			    $sharesData = "`nTotal HashRate: $roundedHashRateTot H/s`nTotal Avg: $roundedAvgTot H/s`nAccepted Shares: $sharesAccepted`nRejected Shares: $sharesRejected`nInvalid Shares: $sharesInvalid`nOutdated Shares: $sharesOutdated`nGood Shares: $goodShares %"
                #Log-Write("$writedata")
                Write-Host -fore Cyan "`n$timeStamp"
                Write-Host -fore Yellow "`nRestarting HashRate Threshold = $roundedRestartHashRate H/s" 
                Write-Host -fore Gray "`n==========================Pool Data==========================`n$poolData"
                Write-Host -fore DarkCyan  "`n=========================Shares Data=========================`n$sharesdata"
                Write-Host -fore DarkGray "`n==========================GPUs Data=========================="
			    for ($i=0; $i -lt $data.devices.Length; $i++) {
				    $device = $data.devices[$i].device
				    #$id = $data.devices[$i].device_id
				    $hashRate = $data.devices[$i].hash_rate
                    $roundedHashRate = [math]::Round($hashRate/1000,2)
				    $avg = $data.devices[$i].hash_rate_avg
                    $roundedAvg = [math]::Round($avg/1000,2)
				    $gpuTemp = $data.devices[$i].gpu_temperature
				    $fanRPM = $data.devices[$i].gpu_fan_rpm
				
				    $writedata = "`n$device | HashRate: $roundedHashRate H/s | Avg: $roundedAvg H/s | Temp: $gpuTemp | Fan RPM: $fanRPM"
				    #Log-Write("$writedata")
                    Write-Host -fore DarkGray "$writedata"
			    } #for ($i=0; $i -lt $data.devices.Length; $i++)
			     Write-Host -fore Gray "`n==========================Status============================="
			    #check if hashRate has changed.
			    if ($hashRateTot -eq $previousRateTot) {
				    $attempt = $attempt +1
				    $reason = "HashRate hasn't changed.  Cast may be fozen"
				    Log-Write("$timeStamp $reason")
				    Write-Host -fore Red "`n$reason"
                } else {
                    #check if hashRate has dropped.
			        if ($hashRateTot -lt $restartHashRate) {
				        $attempt = $attempt +1
				        $reason = "HashRate is below expected value."
				        Log-Write("$timeStamp $reason")
                        Log-Write("      HashRate = $roundedHashrateTot H/s.   expected value = $roundedRestartHashRate H/s")
	    			    Write-Host -fore Red "`n$reason"
                        Write-Host -fore Red "`n       HashRate = $roundedHashrateTot H/s.   expected value = $roundedRestartHashRate H/s"
			        } else {
				        $attempt = 0
					    Write-Host -fore Green "`nHash Rate OK. HashRate = $roundedHashrateTot H/s"
				    } # else ($hashRateTot -lt $restartHashRate)
			    } # else ($hashRateTot -eq $previousRateTot)
            
                #update previous hashRateTotal
                $previousRateTot = $hashRateTot

		    } #	else ($rawData -eq $null)
        
	    } while ($attempt -lt $maxFail)

	    $timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
	    Write-Host -fore Red "`n$timeStamp $reason restarting in 10 seconds"
	    Log-Write("$timeStamp $reason.  Restarting script in 10 seconds")
    }
	
}


function Kill-Miner {
    if ($useStak) {
    $process =  $stakStart
    }
    else {
    $process =  $castStart
    }

	try
	{
		$prog = ($process -split "\.", 2)
		$prog = $prog[0]
		# get STAK process
		$PROC = Get-Process $prog -ErrorAction SilentlyContinue
		if ($PROC) {
			# try gracefully first
			$PROC.CloseMainWindow() | Out-Null
			# kill after five seconds
			Sleep 5
			if (!$PROC.HasExited) {
				$PROC | Stop-Process -Force | Out-Null
			}
			if (!$PROC.HasExited) {
				Write-host -fore Red "Failed to kill the process $prog"
				Write-host -fore Red "`nIf we don't stop here STAK would be invoked"
				Write-host -fore Red "`nover and over until the PC crashed."
				Write-host -fore Red "`n`n That would be very bad."
				Write-host -fore Red 'Press any key to EXIT...';
				$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
				$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
				log-Write ("$timeStamp	Failed to kill $prog")
				EXIT
			}
			Else
			{
				Write-host -fore Green "Successfully killed the process $prog"
				$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
				log-Write ("$timeStamp $prog closed successfully")
			}
		}
		Else
		{
			#Write-host -fore Green "`n$prog process was not found"
			#$timeStamp = "{0:yyyy-MM-dd_HH:mm}" -f (Get-Date)
			#log-Write ("$timeStamp	$prog process was not found")
		}
	}
	Catch
	{
			Write-host -fore Red "Failed to kill the process $prog"
			Write-host -fore Red "`nIf we don't stop here STAK would be invoked"
			Write-host -fore Red "`nover and over until the PC crashed."
			Write-host -fore Red "`n`n That would be very bad."
			Write-host -fore Red 'Press any key to EXIT...';
			$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
			$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
			log-Write ("$timeStamp	Failed to kill $prog")
			EXIT
	}

   
}

function Call-Self {
	Start-Process -FilePath "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Powershell.exe" -ArgumentList .\$scriptName -WorkingDirectory $PSScriptRoot -NoNewWindow
	EXIT
}
function Call-PreHashMonitor {
	Start-Process -FilePath "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Powershell.exe" -ArgumentList .\$preHashMonitor -WorkingDirectory $PSScriptRoot -NoNewWindow
	EXIT
}
#########END FUNCTIONS#########

$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
Log-Write("$timeStamp ========== Script Started ==========")

#relaunch if not admin
Force-Admin $script:MyInvocation
Resize-Console

#restart_GPU

if ($overdriveStart) { #if overdriveStart is defined run it.
	Run-Overdrive
}
set-ENVVars
Start-Sleep -s 3

Start-Mining

if($useStak) {
Start-Sleep -s $sleepBeforeCheck
}


Check-HashRate

Kill-Miner

$timeStamp = "{0:[dd/MM/yyyy - HH:mm:ss]}" -f (Get-Date)
Log-Write("$timeStamp ========== Script Ended ==========")

Call-Self
#Call-PreHashMonitor 


##### If we reach this point we have failed #####
Exit
