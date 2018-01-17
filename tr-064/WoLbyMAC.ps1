###################################################################################
#                                                                                 #
# Wake-on-LAN for a known device via TR-064 function from FRITZ!OS                #
#                                                                                 #
###################################################################################
#                                                                                 #
# You need the MAC address of a LAN device, which must be known to your FRITZ!OS- #
# based router, and an user account with administrative rights, to wake up a LAN  #
# client from sleeping, using this script.                                        #
#                                                                                 #
###################################################################################
Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the username to login to TR-064')][string]$Username,
      [Parameter(Mandatory = $True, Position = 1, HelpMessage = 'the password to login to TR-064')][string]$Password,
      [Parameter(Mandatory = $True, Position = 2, HelpMessage = 'the MAC address of device to wake up')][string]$MAC,
      [Parameter(Mandatory = $False, Position = 3, HelpMessage = 'the internal TR-064 (TLS protected) port, defaults to 49443')][string]$Port = 49443,
      [Parameter(Mandatory = $False, Position = 4, HelpMessage = 'the IP address of the FRITZ!Box, defaults to 192.168.178.1')][string]$Address = "192.168.178.1")

$WebClient = New-Object System.Net.WebClient
$xml_query='<?xml version="1.0"?><s:Envelope xmlns:s="http:#schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http:#schemas.xmlsoap.org/soap/encoding/"><s:Body><u:X_AVM-DE_WakeOnLANByMACAddress xmlns:u="urn:dslforum-org:service:Hosts:1"><NewMACAddress>' + $MAC + '</NewMACAddress></u:X_AVM-DE_WakeOnLANByMACAddress></s:Body></s:Envelope>'

$WebClient.Encoding = [System.Text.Encoding]::UTF8
$WebClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$WebClient.Headers.Set("Content-Type", 'text/xml; charset="utf-8"')
$WebClient.Headers.Set("SOAPACTION", 'urn:dslforum-org:service:Hosts:1#X_AVM-DE_WakeOnLANByMACAddress')
$response = [xml]$WebClient.UploadString("https://" + $Address + ":" + $Port + "/upnp/control/hosts", $xml_query)

$response.Envelope.Body.InnerXml
