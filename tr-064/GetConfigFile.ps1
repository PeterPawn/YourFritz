# SPDX-License-Identifier: GPL-2.0-or-later
###################################################################################
#                                                                                 #
# get configuration export file from FRITZ!OS via TR-064                          #
#                                                                                 #
###################################################################################
Param([Parameter(Mandatory = $true, Position = 0, HelpMessage = 'the username to login to TR-064')][string]$Username,
      [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'the password to login to TR-064')][string]$Password,
      [Parameter(Mandatory = $false, Position = 2, HelpMessage = 'the filename to save data to, defaults to PowerShell pipe')][string]$Filename,
      [Parameter(Mandatory = $false, Position = 3, HelpMessage = 'the IP address of the FRITZ!Box, defaults to 192.168.178.1')][string]$Address = "192.168.178.1",
      [Parameter(Mandatory = $false, Position = 4, HelpMessage = 'the internal TR-064 (TLS protected) port, defaults to 49443')][string]$Port = 49443)

$servicetype = "DeviceConfig:1"
$controlpoint = "/upnp/control/deviceconfig"
$action = "X_AVM-DE_GetConfigFile"
$inparms = @{
    "NewX_AVM-DE_Password" = $Password
}
# only one output value, no needs to select from XML
# $cfgfileparmname = "NewX_AVM-DE_ConfigFileUrl"

$params = [string]::Empty
# build input parameter list
# the file is encrypted with the password of the user, who's calling the export function
foreach ($param in $inparms.GetEnumerator()) {
    $params = $params + "<" + $param.Name + ">" + $param.Value + "</" + $param.Name + ">"
}
$body = '<?xml version="1.0"?><s:Envelope xmlns:s="http:#schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http:#schemas.xmlsoap.org/soap/encoding/"><s:Body><u:' + $action + ' xmlns:u="urn:dslforum-org:service:' + $servicetype + '">' + $params + '</u:' + $action + '></s:Body></s:Envelope>'

$headers = @{
    "Content-Type" = 'text/xml; charset="utf-8"'
    "SOAPACTION" = 'urn:dslforum-org:service:' + $servicetype + '#' + $action
}

$pw = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($Username, $pw)
$uri = "https://" + $Address + ":" + $Port + $controlpoint

try {
    $Error.Clear()
    $response = Invoke-WebRequest -Method "POST" -Credential $credential -Uri $uri -Body $body -Headers $headers -SkipHeaderValidation -SkipCertificateCheck
    if ($response.StatusCode -eq 200) {
        $answer = [xml]$response.Content
        $cfgfileurl = $answer.DocumentElement.Body.FirstChild.InnerText
        $cfgfilereq = Invoke-WebRequest -Uri $cfgfileurl -SkipCertificateCheck -Credential $credential
        if ($cfgfilereq.StatusCode -eq 200) {
            if ($null -eq $cfgfilereq.Encoding) {
                $encoding = New-Object System.Text.UTF8Encoding
            }
            else {
                $encoding = $cfgfilereq.Encoding
            }
            $cfg = $encoding.GetString($cfgfilereq.Content)
            if ($Filename.Length -eq 0) {
                # write read data into pipe
                $cfg
            }
            else {
                try {
                    Out-File -FilePath $Filename -NoClobber -InputObject $cfg
                }
                catch {
                    foreach ($err in $Error.GetEnumerator()) { Write-Host $err.ToString() }
                }
            }
        }
    }
}
catch {
    foreach ($err in $Error.GetEnumerator()) { Write-Host $err.ToString() }
}
