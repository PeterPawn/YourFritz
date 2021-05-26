#######################################################################################
#                                                                                     #
# PowerShell script to find an AVM bootloader (while the device is starting) via      #
# UDP broadcast                                                                       #
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
Param([Parameter(Mandatory = $False, Position = 0, HelpMessage = 'the number of packets to be sent, with 1 second delay in-between (default are 30 packets, resulting in round about 30 seconds for discovery)')][int]$maxWait = 30,
      [Parameter(Mandatory = $False, Position = 1, HelpMessage = 'the IP address, which the device should use (defaults to 192.168.178.1)')][string]$requested_address,
      [Parameter(Mandatory = $False, Position = 2, HelpMessage = 'the interface address to connect from, if there are multiple interfaces and/or multiple addresses')][string]$if_address = "",
      [Parameter(Mandatory = $False, Position = 3, HelpMessage = 'do not hold up the device in the bootloader')][bool]$nohold = $False,
      [Parameter(Mandatory = $False, Position = 4, HelpMessage = 'the broadcast address to use')][String]$bc_address = "255.255.255.255",
      [Parameter(Mandatory = $False, Position = 5, HelpMessage = 'the port number to use')][int]$discovery_port = 5035
)

if ($PSBoundParameters["Debug"] -and $DebugPreference -eq "Inquire") { $DebugPreference = "Continue" }

# our own IP address, we use it to determine an address for EVA, if none was provided
# Oops ... Get-NetIPAddress is only avaiblable in Windows 8 and above ... uncomment it if it's needed, but it's not really used yet and if someone has an unusual network configuration,
# he/she can specify the address to be used as 2nd argument
if ($requested_address.Length -eq 0) {
#    $my_address = Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred | Where { $_.IPAddress -ne "127.0.0.1" } | Select -First 1 IPAddress -ExpandProperty IPAddress
    $requested_address = "192.168.178.1"
}
else {
#    $my_address = Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred | Where { $_.IPAddress -ne "127.0.0.1" } | Select -First 1 IPAddress -ExpandProperty IPAddress
}
# get address part into $Matches
if (-not ($requested_address -match "^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$")) {
    Write-Error -Message "Invalid IP address '$requested_address' specified."
    return $False
}
$a1 = $Matches[1]
$a2 = $Matches[2]
$a3 = $Matches[3]
$a4 = $Matches[4]

$Error.Clear()

# our discovery packet
[System.Byte[]]$discovery_packet = 0,0,                 # 16 bits of zero
                                   18,                  # one byte of 18
                                   1,                   # one byte of 1
                                   1,0,0,0,             # little endian 1 in 32 bits
                                   $a1,$a2,$a3,$a4,     # the requested IP address, will be overwritten if needed
                                   0,0,0,0              # 32 zero bits

# the address of EVA found
$EVA_IP = ""
$EVA_found = $False

# first send out an UDP packet to the requested target address to punch a hole through a possibly existing firewall and to check, whether a box is already waiting at the specified address
try {
    # our listener and its endpoint
    $listener_ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $discovery_port)
    $requested_ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($requested_address), $discovery_port)
    $listener = New-Object System.Net.Sockets.UdpClient $listener_ep
    # we're reading in non-blocking mode, until all received packets are handled
    $listener.Client.Blocking = $False
    $listener_ready = $True
    if ($requested_ep.Address.Address -ne 0) {
        $sent = $listener.Send($discovery_packet, $discovery_packet.Length, $requested_ep)
        try {
            $listener.Client.Blocking = $True
            $listener.Client.ReceiveTimeout = 100
            $answer = $listener.Receive([ref]$listener_ep)
            if ($listener_ep.Port -eq $discovery_port) {
                # the device seems to be waiting already, do not run a FTP session, regardless of 'nohold' setting
                Write-Debug "Received UDP packet as immediate unicast answer from $($listener_ep.Address.ToString()):$($listener_ep.Port.ToString()) ..."
                $EVA_IP = $listener_ep.Address.ToString()
                $EVA_found = $True
                $listener.Close()
            }
        }
        catch
        {
            $listener.Client.Blocking = $False
            $EVA_found = $False
        }
    }
    else {
        # enforce firewall dialog from system, it's not possible to punch a hole automatically
        Write-Warning "If a firewall exception dialog will be shown, you have to allow listening for incoming UDP packets for both private and public networks."
        $listener.Client.Blocking = $True
        $listener.Client.ReceiveTimeout = 5000
        try {
            $dummy = $listener.Receive([ref] $listener_ep)
        }
        catch {
        }
        finally {
            $listener.Client.Blocking = $False
        }
    }
}
catch {
    Write-Verbose "Error creating UDP listener instance`n$($Error[0].ToString())"
    if ($listener) {
        $listener.Close()
    }
    return $False
}

if (-not $EVA_found) {
    try {
        # our IPEndPoint for the discovery packet to send as broadcast
        $bc_ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($bc_address), $discovery_port)
        # the UdpClient to be used for sending the broadcast
        $sender = New-Object System.Net.Sockets.UdpClient
        $sender.EnableBroadcast = $True
        $sender.ExclusiveAddressUse = $False
        if ($if_address.Length -ne 0) {
            $local_ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($if_address), 0)
            $sender.Client.Bind($local_ep)
        }
        else {
            if ($requested_ep.Address.Address -ne 0) {
                try {
                    $localip_client = New-Object System.Net.Sockets.UdpClient
                    $localip_client.Connect($requested_ep)
                    if ($localip_client.Client.Connected) {
                        $local_ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($localip_client.Client.LocalEndPoint.Address.ToString()), 0)
                        Write-Debug "Using local IPv4 address $($local_ep.Address.ToString()) ..."
                        $sender.Client.Bind($local_ep)
                    }
                    else {
                        Write-Debug "Unable to determine local IPv4 address for broadcasts to $requested_address, use if_address parameter, if automatic selection does not work as expected"
                    }
                    $localip_client.Close()
                }
                catch {
                    Write-Debug "Unable to determine local IPv4 address for broadcasts to $requested_address, enable (from firewall dialog) inbound UDP traffic to PowerShell and use if_address parameter, if automatic selection does not work as expected"
                }
            }
            else {
                Write-Verbose "Determining the current IP address of the router may fail, if the default interface is the wrong one or has multiple IP addresses - please use if_address parameter to specify your own address."
            }
        }
        $sender_ready = $True
    }
    catch {
        Write-Verbose "Error creating broadcast sender instance`n$($Error[0].ToString())"
        if ($sender) {
            $sender.Close()
        }
        if ($listener) {
            $listener.Close()
        }
        return $False
    }

    # send the packet until an answer was received
    for ($i = 0; $i -lt $maxWait; $i++) {
        # send out a new discovery packet
        Write-Verbose "Sending discovery packet ($($i + 1)) ..."
        $sent = $sender.Send($discovery_packet,$discovery_packet.length,$bc_ep)
        # read all pending packets
        $loopReceive = $True
        while ($loopReceive) {
            # clear the errors collection first
            $Error.Clear();
            try {
                # try to receive a packet
                $answer = $listener.Receive([ref]$listener_ep)
                if ($answer.Length -eq 16) {
                    # packet exists, check remote port
                    if ($listener_ep.Port -eq $discovery_port) {
                        Write-Debug "Received UDP packet from $($listener_ep.Address.ToString()):$($listener_ep.Port.ToString()) ..."
                        # an answer from the discovery port is from EVA
                        $EVA_IP = $listener_ep.Address.ToString()
                        Write-Verbose "Found EVA loader at $EVA_IP ..."
                        # terminate the loop
                        $loopReceive = $False
                        $EVA_found = $True
                        if (-not $nohold) {
                            Write-Verbose "Trying to connect to the FTP port to hold up the device in bootloader ..."
                            try {
                                [string]$ftpuri = 'ftp://'+$EVA_IP
                                [System.Net.FtpWebRequest]$ftpreq = [System.Net.WebRequest]::Create($ftpuri)
                                $ftpreq.Credentials = New-Object System.Net.NetworkCredential('adam2', 'adam2')
                                $ftpreq.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
                                $ftpresp = $ftpreq.GetResponse()
                                $ftpresp.Close()
                            }
                            catch {
                                if (-not $_.Exception.Message.Contains('(502) Command not implemented.')) {
                                    Write-Debug "Error during FTP connection attempt ..."
                                }
                            }
                        }
                    }
                }
            }
            catch {
                # usually no packet available, send next discovery packet
                $Error.Clear()
                $loopReceive = $False
            }
        }
        # we've found the device, needless to wait again
        if ($EVA_found -eq $True) {
            break
        }
        # wait one second, before the next round is started
        Start-Sleep 1
    }
}
# close network sockets
if ($listener) {
    $listener.Close()
}
if ($sender) {
    $sender.Close()
}
# notify caller
Write-Output "EVA_IP=$EVA_IP"
return $($EVA_IP.Length -gt 0)
