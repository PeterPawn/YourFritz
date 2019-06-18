# SPDX-License-Identifier: GPL-2.0-or-later
Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the username to login to TR-064')][string]$Username,
      [Parameter(Mandatory = $True, Position = 1, HelpMessage = 'the password to login to TR-064')][string]$Password,
      [Parameter(Mandatory = $False, Position = 2, HelpMessage = 'the new value of the UpgradesManaged property, defaults to 0')][int]$NewValue = 0,
      [Parameter(Mandatory = $False, Position = 3, HelpMessage = 'the IP address of the FRITZ!Box, defaults to 192.168.178.1')][string]$Address = "192.168.178.1")

function GetSecurityPort()
{
    Param([Parameter(Mandatory = $False, Position = 0, HelpMessage = 'the IP address of the FRITZ!Box, defaults to 192.168.178.1')][string]$Address = "192.168.178.1")

    $WebClient = New-Object System.Net.WebClient
    $WebClient.Encoding = [System.Text.Encoding]::UTF8
    $WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
    $WebClient.Headers.Set("SOAPACTION", 'urn:dslforum-org:service:DeviceInfo:1#GetSecurityPort')
    $port_query='<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetSecurityPort xmlns:u="urn:dslforum-org:service:DeviceInfo:1"></u:GetSecurityPort></s:Body></s:Envelope>'
    $response = [xml]$WebClient.UploadString("http://" + $Address + ":49000/upnp/control/deviceinfo",$port_query)
    $sslport = $response.Envelope.Body.GetSecurityPortResponse.NewSecurityPort
    return $sslport
}

$WebClient = New-Object System.Net.WebClient
$SSLPort = GetSecurityPort $Address
$WebClient.Encoding = [System.Text.Encoding]::UTF8
$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$getinfo_query='<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetInfo xmlns:u="urn:dslforum-org:service:ManagementServer:1"></u:GetInfo></s:Body></s:Envelope>'

$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Headers.Set("SOAPACTION", 'urn:dslforum-org:service:ManagementServer:1#GetInfo')
$response = [xml]$WebClient.UploadString("https://" + $Address + ":" + $SSLPort + "/upnp/control/mgmsrv", $getinfo_query)
$upgradesManaged_before = $response.Envelope.Body.GetInfoResponse.NewUpgradesManaged

$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Headers.Set("SOAPACTION", 'urn:dslforum-org:service:ManagementServer:1#SetUpgradeManagement')
$setvalue_query='<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetUpgradeManagement xmlns:u="urn:dslforum-org:service:ManagementServer:1"><NewUpgradesManaged>' + $NewValue + '</NewUpgradesManaged></u:SetUpgradeManagement></s:Body></s:Envelope>'
$response = [xml]$WebClient.UploadString("https://" + $Address + ":" + $SSLPort + "/upnp/control/mgmsrv", $setvalue_query)

$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Headers.Set("SOAPACTION", 'urn:dslforum-org:service:ManagementServer:1#GetInfo')
$response = [xml]$WebClient.UploadString("https://" + $Address + ":" + $SSLPort + "/upnp/control/mgmsrv", $getinfo_query)
$upgradesManaged_after = $response.Envelope.Body.GetInfoResponse.NewUpgradesManaged

Write-Host "UpgradesManaged before = " $upgradesManaged_before
Write-Host "UpgradesManaged after = " $upgradesManaged_after
