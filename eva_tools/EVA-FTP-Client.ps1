#######################################################################################
#                                                                                     #
# PowerShell script to communicate with the FTP server in AVM's bootloader            #
#                                                                                     #
#######################################################################################
#                                                                                     #
# Copyright (C) 2010-2016 P.Hämmerlein (packages@yourfritz.de)                        #
#                                                                                     #
# This program is free software; you can redistribute it and/or                       #
# modify it under the terms of the GNU General Public License                         #
# as published by the Free Software Foundation; either version 2                      #
# of the License, or (at your option) any later version.                              #
#                                                                                     #
# This program is distributed in the hope that it will be useful,                     #
# but WITHOUT ANY WARRANTY; without even the implied warranty of                      #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                       #
# GNU General Public License under                                                    #
# http://www.gnu.org/licenses/gpl-2.0.html                                            #
# for more details.                                                                   #
#                                                                                     #
#######################################################################################
Param([Parameter(Mandatory = $False, Position = 0, HelpMessage = 'the IP address, where EVA is awaiting our compliments (holding the apple behind her back), defaults to 192.168.178.1')][string]$Address = "192.168.178.1",
      [Parameter(Mandatory = $False, Position = 1, HelpMessage = 'an optional script block, which will be executed in the context of an active FTP session')][ScriptBlock]$ScriptBlock
)

#######################################################################################
#                                                                                     #
# check the reply of the server for the expected error code                           #
#                                                                                     #
#######################################################################################
function ParseAnswer {
    Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the answer from device')][System.Object]$answer,
          [Parameter(Mandatory = $True, Position = 1, HelpMessage = 'the message ID to look for')][String]$expected
    )

    if ($answer.GetType().ToString() -eq "System.Object[]") {
        for ($i = 0; $i -lt $answer.Count; $i++) {
            $line = $answer[$i] 
            if ($line.GetType().ToString() -eq "System.String" -and $line.Length -gt 0 -and $line.StartsWith($expected)) { 
                return $True
            } 
        }
    }
    else {
        if ($answer.GetType().ToString() -eq "System.String" -and $answer.Length -gt 0 -and $answer.StartsWith($expected)) { 
            return $True 
        }
    }
    return $False
}

#######################################################################################
#                                                                                     #
# read response text from EVA (with a short delay before the 1st read starts), until  #
# no more data is available and return the read lines as string array                 #
#                                                                                     #
#######################################################################################
function ReadAnswer {
    if ($DebugPreference -eq "Inquire") { $DebugPreference = "Continue" } 
    # a large buffer to hold potential answers ... they should never reach 4 KB in one single read from the FTP control channel
    $inputBuffer = New-Object System.Byte[] 4096
    # the whole conversation is ASCII based here
    $encoding = New-Object System.Text.ASCIIEncoding
    [String]$lines = [String]::Empty;
    # short hold, it seems that too early access attempts are unsuccessfully
    Start-Sleep -Milliseconds 100
    $debug = $False
    while ($Global:EVAStream.DataAvailable) {
        $bytesread = $Global:EVAStream.Read($inputBuffer, 0, 4096)
        $lines = [String]::Concat($lines, $encoding.GetString($inputBuffer, 0, $bytesread))
        if ($bytesread -gt 0) { $debug = $True }
    }
    $lines -split "`r`n"
    if ($debug) {
        Write-Debug "Response:`n$lines`n================"
    }
}

#######################################################################################
#                                                                                     #
# write a command to the control channel                                              #
#                                                                                     #
#######################################################################################
function SendCommand {
    Param([ValidateNotNullOrEmpty()][Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the command string to be sent to the server')][string]$command
    )

    if ($DebugPreference -eq "Inquire") { $DebugPreference = "Continue" } 
    # simple as possible, write and flush - could be done without the function call
    $Global:EVAWriter.WriteLine($command)
    $Global:EVAWriter.Flush()
    Write-Debug "Sent`n$command`n================"
}

#######################################################################################
#                                                                                     #
# read a single value from the urlader environment                                    #
#                                                                                     #
#######################################################################################
function GetEnvironmentValue {
    Param([ValidateNotNullOrEmpty()][Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the requested variable')][String]$name
    )
    
    SendCommand "GETENV $name"
    $answer = ReadAnswer
    if (ParseAnswer $answer "200") {
        $answer | Where { $_ } | ForEach { if ($_ -match "^(?'name'$name) *(?'value'.*)$") { Write-Output $Matches["value"] } }
    }
}

#######################################################################################
#                                                                                     #
# set/unset a single value in the urlader environment                                 #
#                                                                                     #
#######################################################################################
function SetEnvironmentValue {
    Param([ValidateNotNullOrEmpty()][Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the variable name')][String]$name,
          [Parameter(Mandatory = $False, Position = 1, HelpMessage = 'the value to set, a missing value leads to an UNSETENV command issued')][String]$value
    )
    
    if ($value -eq $null -or $value.Length -eq 0) { $cmd = "UNSETENV $name" }
    else { $cmd = "SETENV $name $value" }
    SendCommand $cmd
    $answer = ReadAnswer
    return $(ParseAnswer $answer "200")
}

#######################################################################################
#                                                                                     #
# reboot the device                                                                   #
#                                                                                     #
#######################################################################################
function RebootTheDevice {
    SendCommand "REBOOT"
    $answer = ReadAnswer
    return $(ParseAnswer $answer "221")
}

#######################################################################################
#                                                                                     #
# switch to the alternative partition set, no reboot command is issued                #
#                                                                                     #
#######################################################################################
function SwitchSystem {
    $current = GetEnvironmentValue "linux_fs_start"
    # default value, if it's not set
    if ($current -eq $null -or $current.Length -eq 0) { $current = "0" }
    Write-Verbose "current setting - linux_fs_start=$current"
    # switch to the alternative value
    if ($current -ne "1") { $new = "1" } else { $new = "0" }
    Write-Verbose "new setting     - linux_fs_start=$new"
    # set the new value
    if (SetEnvironmentValue "linux_fs_start" $new) {
        Write-Verbose "new value set successfully" 
        return $True
    } 
    else { 
        Write-Output "Error setting new value for 'linux_fs_start' to '$new'." 
        Write-Output $Error
        return $False
    }
}

#######################################################################################
#                                                                                     #
# get the whole environment as file from the device                                   #
#                                                                                     #
#######################################################################################
function GetEnvironmentFile {
    Param([Parameter(Mandatory = $False, Position = 0, HelpMessage = 'the name of file to read, defaults to "env"')][String]$name = "env"
    )

    # set binary transfer mode
    SendCommand "TYPE I"
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "200")) {
        $ex = New-Object System.IO.IOException "Error setting binary transfer mode."
        Throw $ex
    }
    # set media type to SDRAM, retrieving is only functioning in this mode
    SendCommand "MEDIA SDRAM"
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "200")) {
        $ex = New-Object System.IO.IOException "Error selecting media type."
        Throw $ex
    }
    try {
        $file = New-TemporaryFile
        $fname = $file.FullName
    }
    catch {
        $fname = [System.IO.Path]::GetTempFileName()
    }
    if (ReadFile $fname $name) { 
        if (-not ($file)) {
            $file = Get-Item -Path $fname
        }
        Get-Content $file
    }
    Remove-Item $file
}

#######################################################################################
#                                                                                     #
# upload a file to the flash of the device                                            #
#                                                                                     #
#######################################################################################
function UploadFlashFile {
    Param([ValidateNotNullOrEmpty()][Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the file, which has to be uploaded')][String]$filename,
          [ValidateNotNullOrEmpty()][Parameter(Mandatory = $True, Position = 1, HelpMessage = 'the target partition name (e.g. MTDx)')][String]$target
    )

    # set binary transfer mode
    SendCommand "TYPE I"
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "200")) {
        $ex = New-Object System.IO.IOException "Error setting binary transfer mode."
        Throw $ex
    }
    # set media type to flash, we want to write to this memory type
    SendCommand "MEDIA FLSH"
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "200")) {
        $ex = New-Object System.IO.IOException "Error selecting media type."
        Throw $ex
    }
    if (-not (WriteFile $filename $target)) {
        $ex = New-Object System.IO.IOException "Error uploading image file."
        Throw $ex
    }
    return $True
}

#######################################################################################
#                                                                                     #
# start the device from an in-memory image                                            #
#                                                                                     #
#######################################################################################
function BootDeviceFromImage {
    Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the file containing the image to be loaded')][String]$filename
    )    

    if ($DebugPreference -eq "Inquire") { $DebugPreference = "Continue" } 
    if (-not (Test-Path $filename)) {
        $ex = New-Object System.Management.Automation.MethodInvocationException "The specified file cannot be found or accessed." 
        Throw $ex
    }
    $fileattr = Get-Item "$filename"
    $filesize = $fileattr.Length
    if ($filesize -eq 0) {
        $ex = New-Object System.Management.Automation.MethodInvocationException "The specified file is empty."
        Throw $ex
    }
    $memsize = GetEnvironmentValue "memsize"
    # check, if memsize is a multiple of 32 MB, else it's already change by an earlier attempt
    $rem = $memsize % (1024 * 1024 * 32)
    if ($rem -ne 0) {
        $ex = New-Object System.Management.Automation.MethodInvocationException "The memory size was already reduced by an earlier upload, restart the device first."
        Throw $ex
    }
    # compute the needed size values (as strings)
    Write-Debug $("Memory size found    : {0:x8}" -f $memsize)
    Write-Debug $("Image size found     : 0x{0:x8}" -f $filesize)
    $newsize = $memsize - $filesize
    $newmemsize = "0x{0:x8}" -f $newsize
    Write-Debug "Set memory size to   : $newmemsize"
    $firstbyte = 0x80000000
    $startaddr = "0x{0:x8}" -f [System.Int32]$($newsize + $firstbyte)
    $endaddr = "0x{0:x8}" -f [System.Int32]$($newsize + $firstbyte + $filesize)
    Write-Debug "Set MTD ram device to: $startaddr,$endaddr"
    # set the new environment values
    if (-not (SetEnvironmentValue "memsize" "$newmemsize")) {
        $ex = New-Object System.IO.IOException "Setting the new memory size failed."
        Throw $ex
    }
    if (-not (SetEnvironmentValue "kernel_args_tmp" "mtdram1=$startaddr,$endaddr")) {
        $ex = New-Object System.IO.IOException "Setting the temporary kernel parameters failed."
        Throw $ex
    }
    # set binary transfer mode
    SendCommand "TYPE I"
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "200")) {
        $ex = New-Object System.IO.IOException "Error setting binary transfer mode."
        Throw $ex
    }
    # set media type to SDRAM, we'll start from memory
    SendCommand "MEDIA SDRAM"
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "200")) {
        $ex = New-Object System.IO.IOException "Error selecting media type."
        Throw $ex
    }
    if (-not (WriteFile $filename "$startaddr $endaddr")) {
        # try to reset environment settings
        SetEnvironmentValue "memsize" $memsize
        SetEnvironmentValue "kernel_args_tmp"
        # throw error from WriteFile
        $ex = New-Object System.IO.IOException "Error uploading image file."
        Throw $ex
    }
    return $True
}

#######################################################################################
#                                                                                     #
# write a file to the FTP server, the needed preparation have to be done before this  #
# function is called (set transfer mode, select target media type)                    #
#                                                                                     #
#######################################################################################
function WriteFile {
    Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the file name, where the data will be read')][String]$filename,
          [Parameter(Mandatory = $True, Position = 1, HelpMessage = 'the parameters for the "STOR" command')][String]$target,
          [Parameter(Mandatory = $False, Position = 2, HelpMessage = 'the command to be used for passive data transfers, defaults to "P@SW"')][String]$passive_cmd = "P@SW"
    )

    if ($DebugPreference -eq "Inquire") { $DebugPreference = "Continue" } 
    Write-Debug "Uploading file '$filename' to '$target' ..."
    # set passive mode
    SendCommand $passive_cmd
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "227")) {
        $ex = New-Object System.IO.IOException "Error setting passive transfer mode."
        Throw $ex
    }
    # parse passive mode answer: 227 Entering Passive Mode (192,168,178,1,12,10) into named capture groups
    if ($answer[0] -match "^227 Entering Passive Mode \((?'a1'[0-9]{1,3}),(?'a2'[0-9]{1,3}),(?'a3'[0-9]{1,3}),(?'a4'[0-9]{1,3}),(?'p1'[0-9]{1,3}),(?'p2'[0-9]{1,3})\).*$") {
        $data_addr = [System.Net.IPAddress]::Parse($($Matches["a1"]+'.'+$Matches["a2"]+'.'+$Matches["a3"]+'.'+$Matches["a4"])) 
        $data_port = ( [System.Int32]::Parse($Matches["p1"]) * 256 ) + [System.Int32]::Parse($Matches["p2"])
    }
    # open connection and stream
    try {
        $connection = New-Object System.Net.Sockets.TcpClient $data_addr, $data_port
        $stream = $connection.GetStream()
        $file = [System.IO.File]::Open($filename, "Open", "Read")
    }
    catch {
        if ($stream) {
            $stream.Close()
        }
        if ($connection) {
            $connection.Close()
        }
        return $False
    }
    try {
        SendCommand "STOR $target"
        $answer = [String]::Empty
        while ($answer.Length -eq 0) {
            $answer = ReadAnswer
        }
        if (ParseAnswer $answer "150") {
            $sending = $True
            # CopyToAsync is .NET 4.5 and above (as stated by MSDN), but it seems to be available in 4.0 (W7/PS3/CLR4.0)
            #
            # $PSVersionTable
            # Name                           Value
            # ----                           -----
            # PSVersion                      3.0
            # WSManStackVersion              3.0
            # SerializationVersion           1.1.0.1
            # CLRVersion                     4.0.30319.42000
            # BuildVersion                   6.2.9200.16481
            # PSCompatibleVersions           {1.0, 2.0, 3.0}
            # PSRemotingProtocolVersion      2.2
            #
            $copytask = $file.CopyToAsync($stream)
            while ($sending) {
                if ($copytask.IsCompleted) {
                    $stream.Close()
                    $file.Close()
                    $connection.Close()
                    $sending = $False
                    # try to get an answer from the device after closing the data stream and the connection, the response from the device was
                    # very late during my tests
                    Start-Sleep -Milliseconds 5000
                }
                $answer = [String]::Empty
                while ($answer.Length -eq 0) {
                    $answer = ReadAnswer
                }
                if (ParseAnswer $answer "226") {
                    $sending = $False
                    $result = $True
                }
                elseif (ParseAnswer $answer "553") {
                    # may only occur while we're uploading an in-memory image
                    $sending = $False
                    $result = $False
                }
            }
        }
    }
    catch {
        $result = $False
        if ($sending) {
            $stream.Close()
        }
    }
    if ($file) {
        $file.Close()
    }
    if ($connection) {
        $connection.Close()
    }
    return $result
}

#######################################################################################
#                                                                                     #
# read a file from the FTP server                                                     #
#                                                                                     #
#######################################################################################
function ReadFile {
    Param([Parameter(Mandatory = $False, Position = 0, HelpMessage = 'the file name, where the data will be stored; defaults to the pipeline, if no value is given')][String]$filename,
          [Parameter(Mandatory = $False, Position = 1, HelpMessage = 'the (virtual) file name, defaults to "env"')][String]$name = "env",
          [Parameter(Mandatory = $False, Position = 2, HelpMessage = 'the command to be used for passive data transfers, defaults to "P@SW"')][String]$passive_cmd = "P@SW"
    )

    if ($DebugPreference -eq "Inquire") { $DebugPreference = "Continue" } 
    # set passive mode
    SendCommand $passive_cmd
    $answer = ReadAnswer
    if (-not (ParseAnswer $answer "227")) {
        $ex = New-Object System.IO.IOException "Error setting passive transfer mode."
        Throw $ex
    }
    # parse passive mode answer: 227 Entering Passive Mode (192,168,178,1,12,10) into named capture groups
    if ($answer[0] -match "^227 Entering Passive Mode \((?'a1'[0-9]{1,3}),(?'a2'[0-9]{1,3}),(?'a3'[0-9]{1,3}),(?'a4'[0-9]{1,3}),(?'p1'[0-9]{1,3}),(?'p2'[0-9]{1,3})\).*$") {
        $data_addr = [System.Net.IPAddress]::Parse($($Matches["a1"]+'.'+$Matches["a2"]+'.'+$Matches["a3"]+'.'+$Matches["a4"])) 
        $data_port = ( [System.Int32]::Parse($Matches["p1"]) * 256 ) + [System.Int32]::Parse($Matches["p2"])
    }
    # if no file name was specified, we'll use a temporary file and write its content to the pipeline later
    if ($filename.Length -eq 0) {
        try {
            $tempfile = New-TemporaryFile
            $filename = $tempfile.FullName
        }
        catch {
            $filename = [System.IO.Path]::GetTempFileName()
            $tempfile = New-Item -Name $filename
        }
    }
    else {
        $tempfile = $null
    }

    # open connection and stream
    try {
        $connection = New-Object System.Net.Sockets.TcpClient $data_addr, $data_port
        $stream = $connection.GetStream()
    }
    catch {
        if ($stream) {
            $stream.Close()
        }
        if ($connection) {
            $connection.Close()
        }
        return $False
    }
    # open target file
    try {
        $file = [System.IO.File]::Open($filename, "Create", "Write")
    }
    catch {
        $ex = New-Object System.IO.IOException "Error opening output file."
        Throw $ex
    }
    # set timeout on input stream, no more data means end of file
    $stream.ReadTimeout = 500
    # start transfer
    SendCommand "RETR $name"
    $answer = ReadAnswer
    if (ParseAnswer $answer "150") {
        if (-not (ParseAnswer $answer "226")) {
            $receiving = $True
            # receive data stream
            while (-not $stream.DataAvailable) {
                Start-Sleep -Milliseconds 100
            }
            try {
                $copytask = $stream.CopyToAsync($file)
                while ($receiving) {
                    $answer = ReadAnswer
                    if (ParseAnswer $answer "226") {
                        $receiving = $False
                    }
                    elseif ($copytask.IsCompleted) {
                        $receiving = $False
                    }
                }
            }
            catch [System.IO.IOException] {
                # usually our expected timeout, because the connection will not be closed by EVA
                # Write-Debug "Timeout from network stream"
                $receiving = $False
            }
            finally {
                $stream.Close()
            }
        }
        else {
            # short data transfer only, already done 
            try {
                $stream.CopyTo($file)
            }
            catch [System.IO.IOException] {
                # timeout means EOF
            }
            finally {
                $stream.Close()
            }
        }
    }
    elseif (ParseAnswer $answer "501")
    {
        Write-Output "Invalid file name '$name'."
        return $False
    }
    # close file
    if ($file) {
        $file.Close()
    }
    if ($connection) {
        $connection.Close()
    }
    if ($tempfile -ne $null) {
        Get-Content $tempfile
        Remove-Item $tempfile
    }
    else {
        return $True
    }
}

#######################################################################################
#                                                                                     #
# handle login into the EVA session                                                   #
#                                                                                     #
#######################################################################################
function Login {
    Param([Parameter(Mandatory = $False, Position = 2, HelpMessage = 'the user name to be used to login')][String]$username = "adam2",
          [Parameter(Mandatory = $False, Position = 3, HelpMessage = 'the needed password')][String]$password = "adam2"
    )          

    $loggedIn = $False
    $loopRead = $True
    # write the "USER" command
    SendCommand "USER $username"
    $i = 0
    for ($i = 0; $i -lt 10 -and $loopRead; $i++) {
        # ReadAnswer has a delay embedded (100 ms), so hang tight, but be patient (10 loops max. => 1 second delay)
        $answer = ReadAnswer
        if (ParseAnswer $answer "331") {
            SendCommand "PASS $password"
        }
        elseif (ParseAnswer $answer "230") {
            $loggedIn = $True
            $loopRead = $False
        }
    }
    return $loggedIn
}

# init our globals and clear any pending errors
$Global:EVAConnection = $null
$Global:EVAStream = $null
$Global:EVAWriter = $null
$Error.Clear()
# connect now
try {
    # create socket and connect to EVA, this will hold up the device in the "bootloader state", until a "REBOOT" command is issued
    $Global:EVAConnection = New-Object System.Net.Sockets.TcpClient $Address, 21
    # get the underlying stream
    $Global:EVAStream = $Global:EVAConnection.GetStream()
    # open a stream writer for the control channel
    $Global:EVAWriter = New-Object System.IO.StreamWriter $Global:EVAStream
}
catch {
    Write-Host "Error connecting to remote host $EVA_IP`n$($Error[0].ToString())."
    if ($Global:EVAWriter -ne $null) {
        $Global:EVAWriter.Close()
        $Global:EVAWriter = $null
    }
    if ($Global:EVAStream -ne $null) {
        $Global:EVAStream.Close()
        $Global:EVAStream = $null
    }
    if ($Global:EVAConnection -ne $null) {
        $Global:EVAConnection.Close()
        $Global:EVAConnection = $null
    }
    Exit
}

$answer = ReadAnswer
if (ParseAnswer $answer "220") {
    if (Login) {
        SendCommand "SYST"
        $answer = ReadAnswer
        if (ParseAnswer $answer "215 AVM EVA") {
            if ($ScriptBlock) {
                $ScriptBlock.Invoke()
            }
            else {
#####################################################################################
#                                                                                   #
# place your orders here, you may use the provided subfunctions or build your own   #
# command chain                                                                     #
#                                                                                   #
#####################################################################################
# 
# Possible actions are:
#
#            GetEnvironmentFile [ "env" | "count" ]
#            GetEnvironmentValue <name>
#            SetEnvironmentValue <name> [ <value> ]
#            RebootTheDevice
#            SwitchSystem
#            BootDeviceFromImage <image_file>
#            UploadFlashFile <flash_file> <target_partition>
# 
# or you use some lower-level functions (some aren't useful here, it's simply too
# late to login - e.g.) like these:
#
#            SendCommand
#            ReadAnswer
#            ParseAnswer
#            ReadFile
#            WriteFile
#            Login
#
# You may specify your own script block as 2nd argument to this script file, in this
# script block you may use the low- and high-level functions from above.
#
#####################################################################################
#                                                                                   #
# end of "changeable" section, if you modify something outside, please do not ask   #
# or blame the author                                                               #
#                                                                                   #
#####################################################################################
            }
        }
        else {
            Write-Verbose "Unexpected FTP server found:`n$answer"
        }
    }
    else {
        Write-Verbose "Unable to login to EVA."
    }
}
else {
    Write-Verbose "Unexpected answer '$answer' from remote host."
}

# be gentle and close our open stream and socket
$Global:EVAWriter.Close()
$Global:EVAStream.Close()
$Global:EVAConnection.Close()
$Global:EVAWriter.Dispose()
$Global:EVAStream.Dispose()
$Global:EVAConnection.Dispose()
$Global:EVAWriter = $null
$Global:EVAStream = $null
$Global:EVAConnection = $null
