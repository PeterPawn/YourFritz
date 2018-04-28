#######################################################################################################
#                                                                                                     #
# PowerShell support (very limited) for firmware image files from AVM                                 #
#                                                                                                     #
###################################################################################################VER#
#                                                                                                     #
# FirmwareImage.ps1, version 0.8                                                                      #
#                                                                                                     #
# This script is a part of the YourFritz project from https://github.com/PeterPawn/YourFritz.         #
#                                                                                                     #
###################################################################################################CPY#
#                                                                                                     #
# Copyright (C) 2017-2018 P.Haemmerlein (peterpawn@yourfritz.de)                                      #
#                                                                                                     #
###################################################################################################LIC#
#                                                                                                     #
# This project is free software, you can redistribute it and/or modify it under the terms of the GNU  #
# General Public License as published by the Free Software Foundation; either version 2 of the        #
# License, or (at your option) any later version.                                                     #
#                                                                                                     #
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without   #
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      #
# General Public License under http://www.gnu.org/licenses/gpl-2.0.html for more details.             #
#                                                                                                     #
###################################################################################################DOC#
#                                                                                                     #
# This script contains some PowerShell classes to handle linux TAR files, together with extensions    #
# needed for image signature checks and the signing of own images.                                    #
#                                                                                                     #
# There are two relevant classes - FirmwareImage and SigningKey.                                      #
#                                                                                                     #
# The first one (FirmwareImage) provides methods to:                                                  #
#                                                                                                     #
# - read a firmware image from AVM                                                                    #
# - extract archive members with or without removal of a TI checksum at the end of member data        #
# - add a new member to the image                                                                     #
# - verify an existing signature                                                                      #
# - replace an existing signature with an own                                                         #
# - add a new signature                                                                               #
# - create a new image file from scratch                                                              #
#                                                                                                     #
# The second class (SigningKey) may be used to handle RSA keys for firmware signing. It provides:     #
#                                                                                                     #
# - creation of a new RSA key (only 1024-bit keys are supported here)                                 #
# - load and store a RSA private key, with or without password protection                             #
# - load and store the public data of a RSA key                                                       #
#                                                                                                     #
# All other classes are more or less only helpers and are included here to keep all needed code in a  #
# single file for easier handling.                                                                    #
#                                                                                                     #
# You need at least PowerShell version 5 to run the provided code - if you don't use Windows 10, you  #
# may have to install WMF 5.1 from Microsoft first.                                                   #
#                                                                                                     #
# To use any of the provided classes, you may simply include this file into your PowerShell console   #
# session - all you have to execute is the command:                                                   #
#                                                                                                     #
# . <path_to_this_file>\FirmwareImage.ps1                                                             #
#                                                                                                     #
# Afterwards you can use very simple statements to do some complex things ... e.g. you could sign an  #
# already existing image file:                                                                        #
#                                                                                                     #
# [FirmwareImage]::new(<source>).addSignature(<key>,<password>,<output>)                              #
#                                                                                                     #
# where '<source>', '<key>', '<password>' and '<output>' are string values (that means, they are      #
# wrapped with double-quotes) with the following meaning:                                             #
#                                                                                                     #
# source   - the name (incl. path, if needed) of the source image file                                #
# key      - the name (incl. path, if needed) of the file with your RSA private key data              #
# password - the (optional) password to decrypt your private key data                                 #
# output   - the name (incl. path, if needed) of the target file - the freshly signed image file will #
#            be stored at this location                                                               #
#                                                                                                     #
# Without any explicit path specifications, it could look like this (enter all of it on one single    #
# line):                                                                                              #
#                                                                                                     #
# [FirmwareImage]::new("FRITZ.Box_7490.113.06.93.image").addSignature("image_signing.key",            #
# "my_password", "113.06.93-modified.image")                                                          #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# A valid image file is a TAR archive with the old format - therefore you should use the 'tar' applet #
# from BusyBox to create a file the appropriate structure and header contents ... or you use any      #
# other program, which will not add unsupported headers to the file. It looks like AVM uses an own    #
# utility, too - this one encodes the whole content of the 'mode' field from a 'stat()' call into the #
# 'mode' field of a TAR header and not only the 12 least significant bits.                            #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# All changes are only kept in memory (in 'MemoryStream' objects), until you store any data explicit  #
# with a method using an output file. On the other hand this means, that you need enough memory to    #
# hold the whole image data (and more than one instance of it, because it will be copied/clone by     #
# some methods) - as long as your image file will not exceed 'usual' sizes, you should not run into   #
# any problem. Most FRITZ!Box devices lack enough memory to unpack really large image files, too - so #
# it's useless to create very large files.                                                            #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# Class SigningKey                                                                                    #
#                                                                                                     #
# There are five overloaded constructors:                                                             #
#                                                                                                     #
# SigningKey()                                                                                        #
# - create a new RSA key with 1024 bits                                                               #
#                                                                                                     #
# SigningKey([SigningKey] $source)                                                                    #
# - create a new RSA key with the same data as $source                                                #
#                                                                                                     #
# SigningKey([SigningKey] $source, [bool] $onlyPublicData)                                            #
# - create a new RSA key with the same data as $source, optionally drop private data from the new key #
#   if $onlyPublicData is $true                                                                       #
#                                                                                                     #
# SigningKey([string] $xmlFormattedKey)                                                               #
# - create a new RSA key and load the RSA key data from the specified XML structure, which could be   #
#   the result of an earlier call to 'toXmlString()' method                                           #
#                                                                                                     #
# SigningKey([System.Security.Cryptography.RSAParameters] $rsaParameters)                             #
# - create a new RSA key with the specified key parameters                                            #
#                                                                                                     #
# Properties:                                                                                         #
#                                                                                                     #
# [System.Security.Cryptography.RSA] $rsa                                                             #
# - the 'wrapped' RSA implementation, if you want to use any of its properties or methods directly    #
#                                                                                                     #
# The following methods are provided to extract/save key data in various formats:                     #
#                                                                                                     #
# [string] toXmlString([bool] $withPrivateData)                                                       #
# - get a XML string with the key parts - this data isn't encrypted in any way and your private key   #
#   data is completely unprotected, if you store this string anywhere without further precautions     #
#                                                                                                     #
# [string] toAVMModulus()                                                                             #
# - get only the modulus as part of the public key data, the exponent is assumed to be '0x010001' or  #
#   65537 in any case                                                                                 #
# - the returned value is per definition an unsigned integer in hexadecimal representation - there's  #
#   no leading zero, if the high order bit of data is set                                             #
# - as a result, this string will contain exactly 256 characters - that's important, if you want to   #
#   store your own public key data in a variable from the 'urlader environment'                       #
#                                                                                                     #
# [System.IO.MemoryStream] toASCStream()                                                              #
# - get a 'MemoryStream' object with the presentation of the public key parts in AVM's format         #
#                                                                                                     #
# [void] toASCFile([string] $fileName)                                                                #
# - create the file '$fileName' with the public key data in AVM's format                              #
#                                                                                                     #
# [byte[]] toDER([bool] $withPrivateData)                                                             #
# - get the ASN.1 encoded presentation of key data, optionally with private data, if $withPrivateData #
#   is ... [tension in the air] ... $true                                                             #
# - there's no protection for sensitive data in this format                                           #
#                                                                                                     #
# [System.IO.MemoryStream] toDERStream([bool] $withPrivateData)                                       #
# - get a 'MemoryStream' object with the DER presentation of key data, with or without the private    #
#   parts                                                                                             #
# - look at 'toDER' method for comments regarding security of DER encoded data                        #
#                                                                                                     #
# [void] toDERFile([bool] $withPrivateData, [string] $outputFileName)                                 #
# - store the DER encoded RSA key (with/without private parts) to the specified file                  #
# - look at 'toDER' method for comments regarding security of DER encoded data                        #
#                                                                                                     #
# [byte[]] toRSAPublicKey()                                                                           #
# [System.IO.MemoryStream] toRSAPublicKeyStream()                                                     #
# [void] toRSAPublicKeyFile([string] $outputFileName)                                                 #
# - retrieve public parts of the key in PEM format (Base64 encoded DER data with marker lines)        #
# - get data as byte array or 'MemoryStream' object or store it to the specified file                 #
#                                                                                                     #
# [byte[]] toRSAPrivateKey([string] $keyPassword)                                                     #
# [System.IO.MemoryStream] toRSAPrivateKeyStream([string] $keyPassword)                               #
# [void] toRSAPrivateKeyFile([string] $outputFileName, [string] $keyPassword)                         #
# - retrieve the RSA key (incl. private data) in PEM format, optionally with encryption (AES-128 with #
#   CBC), if $password is not empty and not $null                                                     #
# - get data as byte array or 'MemoryStream' object or store it to the specified file                 #
# - the format is the same, as the one from OpenSSL - especially the key derivation from $password is #
#   implemented like EVP_BytesToKey with 1 iteration and without IV output                            #
#                                                                                                     #
# If you want to load any existing key data from a file, you may use the following static methods of  #
# the SigningKey class - all of them return a new SigningKey object:                                  #
#                                                                                                     #
# static [SigningKey] FromASCFile([string] $fileName)                                                 #
# static [SigningKey] FromRSAPublicKeyFile([string] $fileName)                                        #
# static [SigningKey] FromRSAPublicKeyDER([byte[]] $data)                                             #
# static [SigningKey] FromRSAPrivateKeyFile([string] $fileName)                                       #
# static [SigningKey] FromRSAPrivateKeyFile([string] $fileName, [string] $keyPassword)                #
# static [SigningKey] FromRSAPrivateKeyDER([byte[]] $data)                                            #
# static [SigningKey] FromDERFile([string] $fileName, [bool] $isPublicKey)                            #
# static [SigningKey] FromDERFile([string] $fileName)                                                 #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# Class FirmwareImage                                                                                 #
#                                                                                                     #
# Constructors:                                                                                       #
#                                                                                                     #
# FirmwareImage([string] $fileName)                                                                   #
# - create a new instance and load the specified file into it                                         #
#                                                                                                     #
# Properties:                                                                                         #
#                                                                                                     #
# [string] $imageName                                                                                 #
# - the name of the image file on disk, used to load/store data from/to file                          #
#                                                                                                     #
# [TarMember] $signature                                                                              #
# - the TAR member, which holds the current signature, if any                                         #
#                                                                                                     #
# Properties from the base class TarFile:                                                             #
#                                                                                                     #
# [System.Collections.ArrayList] $members                                                             #
# - an array list with the current dictionary of the TAR file                                         #
# - look at the TarMember class for further info about properties and methods or use the PowerShell   #
#   functions (Get-Member, etc.) to investigate a little bit yourself                                 #
#                                                                                                     #
# Methods provided by FirmwareImage class:                                                            #
#                                                                                                     #
# [void] Open([string] $fileName)                                                                     #
# - open the specified file and load its content, discards any older data from this instancecontent   #
#                                                                                                     #
# [void] Save()                                                                                       #
# [void] SaveTo([string] $outputFileName)                                                             #
# - save the current content to the specified file or to the file, from which it was loaded           #
# - the first variant isn't really safe, there's no backup of the previous content and an error may   #
#   lead to complete loss of data                                                                     #
#                                                                                                     #
# [System.IO.MemoryStream] extractMemberAndRemoveChecksum([TarMember] $member)                        #
# [void] extractMemberAndRemoveChecksum([TarMember] $member, [string] $outputName)                    #
# - extract data of the specified TAR member from file and remove a TI checksum, if any               #
# - the second variant saves the data to specified file                                               #
# - to keep a TI checksum at the end of member data, use the 'extractMember' method from base class   #
#                                                                                                     #
# [bool] verifySignature([SigningKey[]] $keys)                                                        #
# [bool] verifySignature([string[]] $keyFileNames)                                                    #
# [bool] verifySignature([string] $keyFileName)                                                       #
# - verify the signature of this image (it has to be signed already or an exception is thrown) with   #
#   (one of) the specified public keys, either an already prepared SigningKey object or the keys from #
#   files using AVM's own format                                                                      #
#                                                                                                     #
# [void] addSignature([SigningKey] $key)                                                              #
# [void] addSignature([string] $keyFileName, [string] $password)                                      #
# - add a new signature (or replace an existing one), using the specified RSA key (with private data) #
# - with the second variant, the key data is loaded from the specified file, which may be encrypted   #
# - the signature is only added/updated in the members array of the base class TarFile                #
#                                                                                                     #
# [void] addSignature([SigningKey] $key, [string] $outputFileName)                                    #
# [void] addSignature([string] $keyFileName, [string] $password, [string] $outputFileName)            #
# - add a new signature (or replace an existing one), using the specified RSA key (with private data) #
# - with the second variant, the key data is loaded from the specified file, which may be encrypted   #
# - the signature is added to the members dictionary of the base class and - finally - the new        #
#   content is written to the specified file                                                          #
#                                                                                                     #
# [void] resetSignature()                                                                             #
# - remove an existing signature from the instance                                                    #
#                                                                                                     #
# [void] removeMember([TarMember] $member)                                                            #
# [void] addMember([TarMember] $member)                                                               #
# [void] insertMember([TarMember] $member, [int] $position)                                           #
# - remove or add a member from/to archive, insert is the same as add in the specified position       #
# - each of this methods will invalidate an existing signature                                        #
#                                                                                                     #
# [System.IO.MemoryStream] extractMember([TarMember] $member)                                         #
# [void] extractMember([TarMember] $member, [string] $outputName)                                     #
# - get data of the specified member as 'MemoryStream' object or store it to the specified file       #
#                                                                                                     #
# [TarMember] getMemberByName([string] $memberName)                                                   #
# - search the TAR members for an entry with the specified name (exact match)                         #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# Known problems/difficulties/inconsistencies:                                                        #
#                                                                                                     #
# Because property values of a PowerShell class are always accessible by the caller, it's possible to #
# change their value (or use their methods, if the property value is another object) without any      #
# chance for the class code to get notified about this.                                               #
# So you may change the data stream of a TarMember object and the TarFile object, wherein this member #
# is contained, does not register this and assumes, an existing signature is still valid.             #
#                                                                                                     #
# If you change any property of a TarMember object or the assigned data stream, you should call the   #
# 'sealContent' method of this object to re-compute the CRC32 values for header and data. At the same #
# zime you should consider to call the 'resetSigned' method of the FirmwareImage class to ensure,     #
# that no further signature verification could take place. If you later decide to add your own        #
# signature, the 'sealContent' method will be called automatically for each existing member.          #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# And now ... let's start with some code - there were enough words written now and you should be able #
# to use this utility file (and the contained classes) for your own purposes, if you have to handle   #
# firmware images from AVM or for AVM's devices.                                                      #
#                                                                                                     #
#######################################################################################################
Write-Host @'
This is "FirmwareImage.ps1" ...

a collection of PowerShell classes to handle AVM's firmware image files

... from the YourFritz project at https://github.com/PeterPawn/YourFritz

(C) 2017-2018 P. Haemmerlein (peterpawn@yourfritz.de)

'@;
Write-Host -ForegroundColor Yellow "Look at the comment lines from the beginning of this file to get further info, how to make use of the provided classes.$([System.Environment]::NewLine)";

Write-Host -ForegroundColor Green "The classes are now ready to be used in this session.";
#######################################################################################################
#                                                                                                     #
# 'Add-Type' may only be called once in a session for the same type - therefore we check, if our own  #
# type is known already and if not, we'll add it to this session in the 'catch' block.                #
#                                                                                                     #
#######################################################################################################
try
{
    [YourFritz.CRC32] | Get-Member | Out-Null;
    Write-Host -ForegroundColor Red "The inline type definitions were NOT updated.";
}
catch
{
    #######################################################################################################
    #                                                                                                     #
    # calculate a CRC32 value according to the rules for a TI checksum in AVM's firmware                  #
    # - this is an inline type, which will be really compiled to IL code ... so it's much faster than a   #
    #   pure PowerShell based version                                                                     #
    # - TI variant uses the "normal" polynomial (0x(1)04C11DB7) and an initial remainder of all zeros,    #
    #   while the final value is complemented                                                             #
    # - the (non-zero) bytes (in little endian order) of the size of previously processed data are        #
    #   appended in the last step to get the final checksum value                                         #
    #                                                                                                     #
    #######################################################################################################
    Add-Type -TypeDefinition @'
namespace YourFritz
{
    public class CRC32
    {
        private System.UInt32 crcPolynomial = 0x04C11DB7;
        private System.UInt32[] crcRemainderTable;
        private System.UInt32 crcRemainder = 0;

        public CRC32()
        {
            this.Reset();
            this.InitRemainderLookupTable();
        }

        public CRC32(System.Byte[] data)
        {
            this.Reset();
            this.InitRemainderLookupTable();
            this.Update(data);
        }

        public CRC32(System.IO.MemoryStream data)
        {
            this.InitRemainderLookupTable();

            System.Byte[] buffer = new System.Byte[32 * 1024];
            int read = 0;

            data.Seek(0, System.IO.SeekOrigin.Begin);
            this.Reset();

            while ((read = data.Read(buffer, 0, buffer.Length)) > 0)
                this.Update(buffer, 0, read);

            data.Seek(0, System.IO.SeekOrigin.Begin);
        }

        private void InitRemainderLookupTable()
        {
            System.UInt32 dividend;
            System.UInt32 remainder;
            System.UInt32 bitPosition;

            this.crcRemainderTable = new System.UInt32[256];

            for (dividend = 0; dividend < 256; dividend++)
            {
                remainder = dividend << 24;
                for (bitPosition = 0; bitPosition < 8; bitPosition++)
                {
                    remainder = ( remainder << 1 ) ^ ( ( remainder & 0x80000000 ) != 0 ? this.crcPolynomial : 0 );
                }
                this.crcRemainderTable[dividend] = remainder;
            }
        }

        public void Update(System.Byte[] data, long index, long count)
        {
            for (long l = 0; l < (index + count); l++)
            {
                this.crcRemainder = (this.crcRemainder << 8) ^ this.crcRemainderTable[(this.crcRemainder >> 24) ^ data[l]];
            }
        }

        public void Update(System.Byte[] data)
        {
            this.Update(data, 0, data.Length);
        }

        public void Update(System.Byte data)
        {
            this.crcRemainder = (this.crcRemainder << 8) ^ this.crcRemainderTable[(this.crcRemainder >> 24) ^ data];
        }

        public System.UInt32 Finish()
        {
            return ~this.crcRemainder;
        }

        public void Reset()
        {
            this.crcRemainder = 0;
        }

        public System.UInt32 OneStep(System.Byte[] data)
        {
            this.Reset();
            this.Update(data);
            return this.Finish();
        }

        public System.UInt32 OneStep(System.IO.Stream data)
        {
            System.Byte[] buffer = new System.Byte[32 * 1024];
            int read = 0;

            data.Seek(0, System.IO.SeekOrigin.Begin);
            this.Reset();

            while ((read = data.Read(buffer, 0, buffer.Length)) > 0)
                this.Update(buffer, 0, read);

            data.Seek(0, System.IO.SeekOrigin.Begin);

            return this.Finish();
        }
    }

    public class Cksum
    {
        private System.UInt32 dataSize;
        private YourFritz.CRC32 crc;

        public Cksum()
        {
            this.dataSize = 0;
            this.crc = new YourFritz.CRC32();
        }

        public void Reset()
        {
            this.crc.Reset();
            this.dataSize = 0;
        }

        public void Update(System.Byte[] data)
        {
            this.crc.Update(data);
            this.dataSize += (System.UInt32) data.Length;
        }

        public void Update(string fileName)
        {
            System.Byte[] data = System.IO.File.ReadAllBytes(fileName);
            this.crc.Update(data);
            this.dataSize += (System.UInt32)data.Length;
        }

        public System.Byte[] Finalize()
        {
            System.UInt32 dataSize = this.dataSize;

            while (dataSize > 0)
            {
                this.crc.Update((System.Byte)(dataSize & 0xFF));
                dataSize = dataSize >> 8;
            }

            System.Byte[] crc = System.BitConverter.GetBytes(this.crc.Finish());

            if (System.BitConverter.IsLittleEndian == false)
                System.Array.Reverse(crc);

            return crc;
        }
    }
}
'@
}

#######################################################################################################
#                                                                                                     #
#  TAR file member types                                                                              #
#                                                                                                     #
#######################################################################################################
Enum TarMemberType
{
    RegularFile = 0;
    Hardlink = 1;
    Symlink = 2;
    CharDevice = 3;
    BlockDevice = 4;
    Directory = 5;
    Pipe = 6;
    Unknown = 255;
}

#######################################################################################################
#                                                                                                     #
#  class to represent a TAR header block from file, where all data is stored in string format         #
#                                                                                                     #
#######################################################################################################
Class TarHeader
{
    # last 100 bytes of file name
    [string] $fileName;
    # mode/permission flags
    [string] $mode;
    # user ID
    [string] $uid;
    # group ID
    [string] $gid;
    # file size
    [string] $size;
    # modification time
    [string] $modTime;
    # file type
    [char] $fileType;
    # target name for link entries
    [string] $linkTarget;
    # group name
    [string] $groupName;
    # user name
    [string] $userName;
    # major device number for special entries
    [string] $majorDevice;
    # minor device number for special entries
    [string] $minorDevice;
    # first 155 bytes of file name, if needed
    [string] $prefixName;

    # create a header from an existing member ... some properties have identical names, but are
    # stored differently here - all properties for an object of this class are strings with octal
    # numbers for numeric (or better non-alphabetic) values
    TarHeader([TarMember] $source)
    {
        if ($source.fileName.Length -gt 100)
        {
            $this.fileName = $source.fileName.Substring($this.fileName.Length - 100);
            $this.prefixName = $source.fileName.Substring(0, $source.fileName.Length - 100);
        }
        else
        {
            $this.fileName = $source.fileName;
            $this.prefixName = [System.String]::Empty;
        }

        $this.mode = [System.Convert]::ToString($source.fileMode, 8);
        $this.uid = [System.Convert]::ToString($source.uid, 8);
        $this.gid = [System.Convert]::ToString($source.gid, 8);
        $this.size = [System.Convert]:: ToString($source.size, 8);
        $this.modTime = [System.Convert]:: ToString($source.modTime, 8);
        $this.fileType = $source.fileType.ToInt32($null).ToString();

        if ($source.fileType -eq [TarMemberType]::Symlink)
        {
            $this.linkTarget = $source.linkTarget.Substring(0, [Math]::Min($source.linkTarget.Length, 100));
        }

        if ($source.userName.Length -gt 0)
        {
            $this.userName = $source.userName.Substring(0, [Math]::Min($source.userName.Length, 32));
        }
        if ($source.groupName.Length -gt 0)
        {
            $this.groupName = $source.groupName.Substring(0, [Math]::Min($source.groupName.Length, 32));
        }

        $this.majorDevice = [System.Convert]::ToString($source.majorDevice, 8);
        $this.minorDevice = [System.Convert]::ToString($source.minorDevice, 8);
        $this.mode = $this.mode.PadLeft(7, '0');
        $this.uid = $this.uid.PadLeft(7, '0');
        $this.gid = $this.gid.PadLeft(7, '0');
        $this.size = $this.size.PadLeft(11, '0');
        $this.modTime = $this.modTime.PadLeft(11, '0');
        $this.majorDevice = $this.majorDevice.PadLeft(7, '0');
        $this.minorDevice = $this.minorDevice.PadLeft(7, '0');
    }

    # build an object from the member header read from archive file
    TarHeader([byte[]] $buffer)
    {
        if ($buffer.Count -ne 512)
        {
            throw "Invalid buffer size, has to be 512 bytes.";
        }

        if ($buffer[257] -ne 117 -or
            $buffer[258] -ne 115 -or
            $buffer[259] -ne 116 -or
            $buffer[260] -ne 97 -or
            $buffer[261] -ne 114 -or
            $buffer[262] -ne 32 -or
            $buffer[263] -ne 32 -or
            $buffer[264] -ne 0)
        {
            throw "Invalid TAR magic at header.";
        }

        [System.Text.Encoding] $ascii = ([System.Text.Encoding]::ASCII);
        [char[]] $trim = (0, 32);

        $this.fileName = $ascii.GetString($buffer, 0, 100).TrimEnd($trim);
        $this.mode = $ascii.GetString($buffer, 100, 8).TrimEnd($trim);
        $this.uid = $ascii.GetString($buffer, 108, 8).TrimEnd($trim);
        $this.gid = $ascii.GetString($buffer, 116, 8).TrimEnd($trim);
        $this.size = $ascii.GetString($buffer, 124, 12).TrimEnd($trim);
        $this.modTime = $ascii.GetString($buffer, 136, 12).TrimEnd($trim);
        $this.fileType = [System.Convert]::ToChar($buffer[156]);
        $this.linkTarget = $ascii.GetString($buffer, 157, 100).TrimEnd($trim);
        $this.userName = $ascii.GetString($buffer, 265, 32).TrimEnd($trim);
        $this.groupName = $ascii.GetString($buffer, 297, 32).TrimEnd($trim);
        $this.majorDevice = $ascii.GetString($buffer, 329, 8).TrimEnd($trim);
        $this.minorDevice = $ascii.GetString($buffer, 337, 8).TrimEnd($trim);
        $this.prefixName = $ascii.GetString($buffer, 345, 155).TrimEnd($trim);

        if ($this.majorDevice.Length -eq 0)
        {
            $this.majorDevice = "0";
        }
        if ($this.minorDevice.Length -eq 0)
        {
            $this.minorDevice = "0";
        }

        [int] $chksum = 0;
        for ([int] $i = 0; $i -lt $buffer.count; $i++)
        {
            if ($i -lt 148 -or $i -ge (148 + 8))
            {
                $chksum += $buffer[$i];
            }
            else
            {
                $chksum += 32;
            }
        }

        if ($chksum -ne [System.Convert]::ToInt32($ascii.GetString($buffer, 148, 8).TrimEnd($trim), 8))
        {
            throw "Invalid header checksum detected.";
        }
    }

    # get the (re-computed) header data block for this member, with checksum, magic, etc.
    [byte[]] toBytes()
    {
        [byte[]] $buffer = [byte[]]::CreateInstance([byte], 512);
        [System.Text.Encoding] $ascii = [System.Text.Encoding]::ASCII;

        $ascii.GetBytes($this.fileName).CopyTo($buffer, 0);
        $ascii.GetBytes($this.mode).CopyTo($buffer, 100);
        $ascii.GetBytes($this.uid).CopyTo($buffer, 108);
        $ascii.GetBytes($this.gid).CopyTo($buffer, 116);
        $ascii.GetBytes($this.size).CopyTo($buffer, 124);
        $ascii.GetBytes($this.modTime).CopyTo($buffer, 136);
        $ascii.GetBytes($this.fileType).CopyTo($buffer, 156);

        if ($this.linkTarget.Length -gt 0)
        {
            $ascii.GetBytes($this.linkTarget).CopyTo($buffer, 157);
        }

        $ascii.GetBytes("ustar  ").CopyTo($buffer, 257);

        if ($this.userName.Length -gt 0)
        {
            $ascii.GetBytes($this.userName).CopyTo($buffer, 265);
        }

        if ($this.groupName.Length -gt 0)
        {
            $ascii.GetBytes($this.groupName).CopyTo($buffer, 297);
        }

        $ascii.GetBytes($this.majorDevice).CopyTo($buffer, 329);
        $ascii.GetBytes($this.minorDevice).CopyTo($buffer, 337);

        if ($this.prefixName.Length -gt 0)
        {
            $ascii.GetBytes($this.prefixName).CopyTo($buffer, 345);
        }

        $ascii.GetBytes("        ").CopyTo($buffer, 148);

        [int] $chksum = 0;
        for ([int] $i = 0; $i -lt $buffer.count; $i++)
        {
            $chksum += $buffer[$i];
        }

        $ascii.GetBytes([System.Convert]::ToString($chksum, 8).PadLeft(7, '0')).CopyTo($buffer, 148);

        return $buffer;
    }
}

#######################################################################################################
#                                                                                                     #
# class to hold data for a single TAR file member - with useful, converted data types                 #
#                                                                                                     #
#######################################################################################################
Class TarMember
{
    # static members with umask for new member creation
    static [int] $umaskFile = [System.Convert]::ToInt32("037", 8);
    static [int] $umaskDir = [System.Convert]::ToInt32("027", 8);
    #
    # instance members
    #
    # member name, build from all header fields containing name parts
    [string] $fileName;
    # mode/permission flags
    hidden [int] $fileMode;
    # octal mode/permissions as string
    [string] $mode;
    # file mode flags as string in "long listing" format
    [string] $displayMode
    # user ID
    [int] $uid;
    # user name
    [string] $userName;
    # group ID
    [int] $gid;
    # group name
    [string] $groupName;
    # file size
    [long] $size;
    # modification time
    [long] $modTime;
    # $modTime as datetime value
    [System.DateTimeOffset] $fileTime;
    # file type
    [TarMemberType] $fileType;
    # target name for link entries
    [string] $linkTarget;
    # major device number for special entries
    [int] $majorDevice;
    # minor device number for special entries
    [int] $minorDevice;
    # member data
    [System.IO.MemoryStream] $data;
    # member header from original data
    [byte[]] $signedHeader;
    # signed header present
    [bool] $hasSignedHeader;
    # CRC32 values for member data and header content, which was used for signing
    [uint32] $crcData;
    [uint32] $crcHeader;

    # create an empty member, the properties have to be set by the caller later
    TarMember()
    {
        $this.fileType = [TarMemberType]::RegularFile;

        $this.fileTime = [System.DateTimeOffset]::Now;
        $this.modTime = $this.fileTime.ToUnixTimeSeconds();

        $this.data = [System.IO.MemoryStream]::new();
        $this.hasSignedHeader = $false;

        if ($this.fileType -eq [TarMemberType]::Directory)
        {
            $this.fileMode = ([System.Convert]::ToInt32("777", 8) -band (-bnot [TarMember]::umaskDir));
        }
        else
        {
            $this.fileMode = ([System.Convert]::ToInt32("666", 8) -band (-bnot [TarMember]::umaskFile));
        }
        $this.mode = [System.Convert]::ToString($this.fileMode, 8).PadLeft(4, '0');
        $this.displayMode = [TarMember]::getDisplayMode($this.fileMode, $this.fileType);
    }

    # create a new member from an existing one ($source)
    # - the new member shares the content stream of $source
    TarMember([TarMember] $source)
    {
        $this.fileName = $source.fileName;
        $this.fileType = $source.fileType;

        $this.fileMode = $source.fileMode;
        $this.mode = [System.Convert]::ToString($this.fileMode, 8).PadLeft(4, '0');
        $this.displayMode = [TarMember]::getDisplayMode($this.fileMode, $this.fileType);

        $this.uid = $source.uid;
        $this.userName = $source.userName;
        $this.gid = $source.gid;
        $this.groupName = $source.groupName;

        $this.size = $source.size;
        $this.data = $source.data;

        $this.modTime = $source.modTime;
        $this.fileTime = $source.fileTime;

        $this.linkTarget = $source.linkTarget;
        $this.majorDevice = $source.majorDevice;
        $this.minorDevice = $source.minorDevice;

        $this.hasSignedHeader = $source.hasSignedHeader;
        if ($source.hasSignedHeader)
        {
            $this.signedHeader = [byte[]]::CreateInstance([byte], $source.signedHeader.Count);
            [System.Array]::Copy($source.signedHeader, 0, $this.signedHeader, 0, $source.signedHeader.Count);
        }

        $this.crcData = $source.crcData;
        $this.crcHeader = $source.crcHeader;
    }

    # create a new member from the specified TarHeader object
    TarMember([TarHeader] $source, # a TarHeader object built from the content of the header
        [byte[]] $signedHeader, # a byte array (optional) with the original header data read from an archive
        [System.IO.Stream] $dataStream # a stream containing the file data, if any
    )
    {
        $this.fileName = $source.fileName;
        $this.fileType = [TarMemberType][System.Convert]::ToInt32($source.fileType, 8);

        $this.fileMode = [System.Convert]::ToInt32($source.mode, 8) -band 0x0FFF;
        $this.mode = [System.Convert]::ToString($this.fileMode, 8).PadLeft(4, '0');
        $this.displayMode = [TarMember]::getDisplayMode($this.fileMode, $this.fileType);

        $this.uid = [System.Convert]::ToInt32($source.uid, 8);
        $this.userName = $source.userName;
        $this.gid = [System.Convert]::ToInt32($source.gid, 8);
        $this.groupName = $source.groupName;

        $this.modTime = [System.Convert]::ToInt32($source.modTime, 8);
        $this.fileTime = [System.DateTimeOffset]::FromUnixTimeSeconds($this.modTime);

        $this.linkTarget = $source.linkTarget;
        $this.majorDevice = [System.Convert]::ToInt32($source.majorDevice, 8);
        $this.minorDevice = [System.Convert]::ToInt32($source.minorDevice, 8);

        $this.size = [System.Convert]::ToInt32($source.size, 8);
        if ($this.size -gt 0)
        {
            [byte[]] $memberData = [byte[]]::CreateInstance([byte], $this.size);
            $dataStream.Read($memberData, 0, $this.size);
            $dataStream.Seek(($dataStream.Position + 511) -band -512, [System.IO.SeekOrigin]::Begin)
            $this.data = [System.IO.MemoryStream]::new($memberData);
            $crc = New-Object YourFritz.CRC32;
            $this.crcData = $crc.OneStep($this.data);
        }
        else
        {
            $this.crcData = 0;
        }

        if ($signedHeader -ne $null -and $signedHeader.Count -gt 0)
        {
            $this.hasSignedHeader = $true;
            $this.signedHeader = [byte[]]::CreateInstance([byte], $signedHeader.Count);
            [System.Array]::Copy($signedHeader, 0, $this.signedHeader, 0, $signedHeader.Count);
            $crc = New-Object YourFritz.CRC32;
            $this.crcHeader = $crc.OneStep($this.signedHeader);
        }
        else
        {
            $this.crcHeader = 0;
        }
    }

    # hidden constructor for static factory methods
    hidden TarMember([TarMemberType] $fileType, [string] $fileName, [System.IO.MemoryStream] $data)
    {
        $this.fileName = $fileName;
        $this.fileType = $fileType;

        if ($this.fileType -eq [TarMemberType]::Directory)
        {
            $this.fileMode = ([System.Convert]::ToInt32("777", 8) -band (-bnot [TarMember]::umaskDir));
        }
        else
        {
            $this.fileMode = ([System.Convert]::ToInt32("666", 8) -band (-bnot [TarMember]::umaskFile));
        }
        $this.mode = [System.Convert]::ToString($this.fileMode, 8).PadLeft(4, '0');
        $this.displayMode = [TarMember]::getDisplayMode($this.fileMode, $this.fileType);

        $this.fileTime = [System.DateTimeOffset]::Now;
        $this.modTime = $this.fileTime.ToUnixTimeSeconds();

        if ($data -ne $null)
        {
            $this.data = $data;
            $this.size = $data.Length;
        }
        else
        {
            $this.data = [System.IO.MemoryStream]::new();
        }

        $this.hasSignedHeader = $false;
    }

    # set new file mode value, refresh dependent properties, invalidate signature
    [void] setMode([int] $newFileMode)
    {
        $this.fileMode = $newFileMode;

        $this.mode = [System.Convert]::ToString($this.fileMode, 8).PadLeft(4, '0');
        $this.displayMode = [TarMember]::getDisplayMode($this.fileMode, $this.fileType);

        $this.hasSignedHeader = $false;
    }

    #    [void] setMode([string] $newMode)
    #    {
    #
    #    }

    # set new user ID value, invalidate signature
    [void] setUID([int] $uid)
    {
        $this.uid = $uid;
        $this.hasSignedHeader = $false;
    }

    # set new user name value, invalidate signature
    [void] setUserName([string] $userName)
    {
        $this.userName = $userName;
        $this.hasSignedHeader = $false;
    }

    # set new user ID and name at once
    [void] setUserNameAndID([string] $userName, [int] $uid)
    {
        $this.setUID($uid);
        $this.setUserName($userName);
    }

    # set new group ID value, invalidate signature
    [void] setGID([int] $gid)
    {
        $this.gid = $gid;
        $this.hasSignedHeader = $false;
    }

    # set new group name value, invalidate signature
    [void] setGroupName([string] $groupName)
    {
        $this.groupName = $groupName;
        $this.hasSignedHeader = $false;
    }

    # set new group ID and name at once
    [void] setGroupNameAndID([string] $groupName, [int] $gid)
    {
        $this.setGID($gid);
        $this.setGroupName($groupName);
    }

    # set new file content and data size, invalidate signature
    [void] setData([System.IO.MemoryStream] $data)
    {
        $this.data = $data;
        if ($data -ne $null)
        {
            $this.size = $this.data.Length;
        }
        else
        {
            $this.size = 0;
        }
        $this.hasSignedHeader = $false;
    }

    # remove any existing data from the member
    [void] removeData()
    {
        $this.setData($null);
    }

    # set new file modification time value (epoch format), invalidate signature
    # it's only hidden to keep the list of visible methods (for auto-completion) somewhat smaller
    [void] setModTime([long] $newTime)
    {
        $this.modTime = $newTime;
        $this.fileTime = [System.DateTimeOffset]::FromUnixTimeSeconds($this.modTime);
        $this.hasSignedHeader = $false;
    }

    # set new file modification time value (datetime format), invalidate signature
    # it's only hidden to keep the list of visible methods (for auto-completion) somewhat smaller
    [void] setModTime([System.DateTimeOffset] $newTime)
    {
        $this.fileTime = $newTime;
        $this.modTime = $this.fileTime.ToUnixTimeSeconds();
        $this.hasSignedHeader = $false;
    }

    # compute new CRC values for the current state (properties, file data) of this instance
    hidden [void] sealContent()
    {
        $crc = New-Object YourFritz.CRC32;

        $this.signedHeader = [TarHeader]::new($this).toBytes();
        $this.hasSignedHeader = $true;
        $this.crcHeader = $crc.OneStep($this.signedHeader);

        if ($this.data -ne $null -and $this.data.Length -gt 0)
        {
            $this.crcData = $crc.OneStep([System.IO.Stream]$this.data);
        }
        else
        {
            $this.crcData = 0;
        }
    }

    # get the complete content for a TAR file (header + file data) of this member
    hidden [System.IO.MemoryStream] getTarContent([bool] $forSigning)
    {
        if ($forSigning)
        {
            if (-not $this.hasSignedHeader)
            {
                throw "No signed/sealed header present here - unable to output signed content.";
            }

            $crc = New-Object YourFritz.CRC32;

            if ($crc.OneStep($this.signedHeader) -ne $this.crcHeader -or
                ($this.size -gt 0 -and $crc.OneStep($this.data) -ne $this.crcData))
            {
                throw ("The original content was changed (member {0}), retrieving of data stream for signing isn't possible." -f $this.fileName);
            }
        }

        if ($this.fileName -eq $null -or $this.fileName.Length -eq 0)
        {
            throw "A member entry needs a file name.";
        }

        [System.IO.MemoryStream] $outputStream = [System.IO.MemoryStream]::new();

        if ($this.hasSignedHeader)
        {
            $outputStream.Write($this.signedHeader, 0, 512);
        }
        else
        {
            $outputStream.Write([TarHeader]::new($this).toBytes(), 0, 512);
        }

        if ($this.size -gt 0)
        {
            $this.data.WriteTo($outputStream);
            [int] $fill = (($this.size + 511) -band -512) - $this.size;
            $outputStream.Write([byte[]]::CreateInstance([byte], $fill), 0, $fill);
        }

        return $outputStream;
    }

    # - static factory methods for new TarMember objects, based on their file type
    # - use them for more readability and to encapsulate additional assignments to property values
    # - there's no factory method for hard-links, they're used seldom

    # create a new TAR file member as empty file
    static [TarMember] newEmptyFile([string] $fileName)
    {
        return [TarMember]::newMember([TarMemberType]::RegularFile, $fileName, [System.IO.MemoryStream]::new());
    }

    # create a new TAR file member with the specified data as content
    static [TarMember] newFile([string] $fileName, [System.IO.MemoryStream] $data)
    {
        return [TarMember]::newMember([TarMemberType]::RegularFile, $fileName, [System.IO.MemoryStream] $data);
    }

    # get a new member for a directory
    static [TarMember] newDirectory([string] $dirName)
    {
        return [TarMember]::newMember([TarMemberType]::Directory, $dirName, $null);
    }

    # get a new member for a symbolic link
    static [TarMember] newSymlink([string] $from, [string] $to)
    {
        [TarMember] $newMember = [TarMember]::newMember([TarMemberType]::Symlink, $from, $null);
        $newMember.linkTarget = $to;
        return $newMember;
    }

    # get a new member for a pipe
    static [TarMember] newPipe([string] $pipeName)
    {
        return [TarMember]::newMember([TarMemberType]::Pipe, $pipeName, $null);
    }

    # get a new member for a character device
    static [TarMember] newCharDevice([string] $devName, [int] $major, [int] $minor)
    {
        [TarMember] $newMember = [TarMember]::newMember([TarMemberType]::CharDevice, $devName, $null);
        $newMember.majorDevice = $major;
        $newMember.minorDevice = $minor;
        return $newMember;
    }

    # get a new member for a block device
    static [TarMember] newBlockDevice([string] $devName, [int] $major, [int] $minor)
    {
        [TarMember] $newMember = [TarMember]::newMember([TarMemberType]::BlockDevice, $devName, $null);
        $newMember.majorDevice = $major;
        $newMember.minorDevice = $minor;
        return $newMember;
    }

    # - all further methods are hidden to keep suggestions list for auto-completion smaller

    # create a new generic TarMember object with the specified property values and file data content
    # it's only hidden to keep the list of visible methods (for auto-completion) somewhat smaller
    hidden static [TarMember] newMember(
        [TarMemberType] $fileType, # file type
        [string] $fileName, # file name
        [System.IO.MemoryStream] $data # file data, if any
    )
    {
        [TarMember] $newMember = [TarMember]::new($fileType, $fileName, $data);
        return $newMember;
    }

    # overloaded method with a byte array for member data
    # it's only hidden to keep the list of visible methods (for auto-completion) somewhat smaller
    hidden static [TarMember] newMember(
        [TarMemberType] $fileType, # file type
        [string] $fileName, # file name
        [byte[]] $data                 # file data, if any
    )
    {
        return [TarMember]::newMember($fileType, $fileName, [System.IO.MemoryStream]::new($data));
    }

    # internal function to get a symbolic representation of mode flags
    hidden static [string] getDisplayMode([int] $fileMode, [TarMemberType] $fileType)
    {
        [string] $type = [System.String]::Empty;
        [string] $show = [System.String]::Empty;
        [int] $mask = $fileMode -band ( ( 7 -shl 6 ) + ( 7 -shl 3 ) + 7 );

        switch ($fileType)
        {
            Symlink { $type = "l"; break; }
            Directory { $type = "d"; break; }
            CharDevice { $type = "c"; break; }
            BlockDevice { $type = "b"; break; }
            Pipe { $type = "p"; break; }
            Default { $type = "-"; break; }
        }

        for ([int] $i = 0; $i -lt 3; $i++)
        {
            if ($mask -band 1)
            {
                if ($i -gt 0 -and $fileMode -band (1 -shl ( 9 + $i )))
                {
                    $show = "s" + $show;
                }
                else
                {
                    $show = "x" + $show;
                }
            }
            else
            {
                if ($i -gt 0 -and $fileMode -band (1 -shl 11) -and $i -eq 0)
                {
                    $show = "S" + $show;
                }
                else
                {
                    $show = "-" + $show;
                }
            }

            if ($mask -band 2)
            {
                $show = "w" + $show;
            }
            else
            {
                $show = "-" + $show;
            }

            if ($mask -band 4)
            {
                $show = "r" + $show;
            }
            else
            {
                $show = "-" + $show;
            }

            $mask = $mask -shr 3;
        }

        return $type + $show;
    }
}

#######################################################################################################
#                                                                                                     #
# represents a complete, generic TAR file                                                             #
# only the old header style ("ustar  " as magic) is supported, because AVM uses only this format yet  #
#                                                                                                     #
#######################################################################################################
Class TarFile
{
    [System.Collections.ArrayList] $members = [System.Collections.ArrayList]::new();
    [long] $garbageAtEnd;

    # create an empty file
    TarFile()
    {
    }

    # create an instance and load the specified file into it
    TarFile([string] $fileName)
    {
        $this.loadTarFile([System.IO.File]::OpenRead($fileName));
    }

    # create a new instance from the specified data stream
    TarFile([System.IO.Stream] $sourceStream)
    {
        $this.loadTarFile($sourceStream);
    }

    # load TAR file dictionary from a stream object
    hidden [void] loadTarFile([System.IO.Stream] $sourceStream)
    {
        [byte[]] $buffer = [byte[]]::CreateInstance([byte], 512);
        [int] $empty_headers = 0;

        $sourceStream.Seek(0, [System.IO.SeekOrigin]::Begin);
        try
        {
            while ($sourceStream.Read($buffer, 0, 512) -eq 512)
            {
                if ($buffer[0] -eq 0)
                {
                    for ([int] $i = 0; $i -lt 512; $i++)
                    {
                        if ($buffer[$i] -ne 0)
                        {
                            $empty_headers = 0;
                            break;
                        }
                    }
                    if ($i -eq 512)
                    {
                        $empty_headers++;
                        if ($empty_headers -ge 2)
                        {
                            $this.garbageAtEnd = $sourceStream.Length - $sourceStream.Position;
                            return;
                        }
                        continue;
                    }
                }
                [TarHeader] $header = [TarHeader]::new($buffer);
                [TarMember] $newMember = [TarMember]::new($header, $buffer, $sourceStream);
                $this.members.Add($newMember);
            }
        }
        catch
        {
            throw ("Error reading TAR file.$([System.Environment]::NewLine){0}" -f $_.Exception.ToString());
        }
    }

    # get the data stream property of the specified member (more or less a 'get' accessor function)
    [System.IO.MemoryStream] extractMember([TarMember] $member)
    {
        return $member.data;
    }

    # write the data stream of the specified member to $outputName
    [void] extractMember([TarMember] $member, [string] $outputName)
    {
        $member.data.WriteTo([System.IO.File]::Create($outputName));
    }

    # search the members collection for an entry with name exactly $memberName (no wildcards)
    [TarMember] getMemberByName([string] $memberName)
    {
        foreach ($member in $this.members)
        {
            if ($member.fileName -eq $memberName)
            {
                return $member;
            }
        }
        throw "Member not found.";
    }

    # remove a member entry from this object
    [void] removeMember([TarMember] $member)
    {
        $this.members.Remove($member);
    }

    # add a new member entry to this object
    [void] addMember([TarMember] $member)
    {
        $this.members.Add($member);
    }

    # add a new member entry to this object and insert it at the given position into the members list
    [void] insertMember([TarMember] $member, [int] $position)
    {
        $this.members.Insert($position, $member);
    }
}

#######################################################################################################
#                                                                                                     #
# verify, add/remove checksum data from the end of a file                                             #
# - if a checksum is present, it starts 8 bytes from the end of file with a magic value of            #
#                                                                                                     #
#   0x23 0xde 0x53 0xc4 (or '( 35, 222, 83, 196 )' as byte array with decimal values                  #
#                                                                                                     #
# - the magic is followed by the CRC value in little endian order                                     #
#                                                                                                     #
#######################################################################################################
Class TIcksum
{
    [System.IO.MemoryStream] $data;

    # create a new instance and assign the specified data to it
    TIcksum([System.IO.MemoryStream] $data)
    {
        $this.data = $data;
    }

    # check, if the content contains a signature (in the last 8 bytes)
    [bool] HasSignature()
    {
        if ($this.data.Length -ge 8)
        {
            $this.data.Seek(-8, [System.IO.SeekOrigin]::End);
            [byte[]] $magic = [System.Byte[]]::CreateInstance([System.Byte], 4);
            $this.data.Read($magic, 0, 4);
            return [TIcksum]::IsMagic($magic);
        }
        return $false;
    }

    # verify an existing TI signature
    [bool] Verify()
    {
        if (-not $this.HasSignature())
        {
            throw "The data stream has no TI checksum yet.";
        }
        $cksum = New-Object YourFritz.Cksum;
        $this.data.Seek(-4, [System.IO.SeekOrigin]::End);
        [byte[]] $value = [System.Byte[]]::CreateInstance([System.Byte], 4);
        $this.data.Read($value, 0, 4);
        [byte[]] $fileData = [System.Byte[]]::CreateInstance([System.Byte], $this.data.Length - 8);
        $this.data.Seek(0, [System.IO.SeekOrigin]::Begin);
        $this.data.Read($fileData, 0, $this.data.Length - 8);
        $this.data.Seek(0, [System.IO.SeekOrigin]::Begin);
        $cksum.Update($fileData);
        [byte[]] $computed = $cksum.Finalize();
        if ($computed[0] -eq $value[0] -and $computed[1] -eq $value[1] -and $computed[2] -eq $value[2] -and $computed[3] -eq $value[3])
        {
            return $true;
        }
        return $false;
    }

    # remove an existing signature from end of file, the size of stream will be lowered appropriate
    [void] Remove()
    {
        if (-not $this.HasSignature())
        {
            throw "The data stream has no TI checksum yet.";
        }
        $this.data.SetLength($this.data.Length - 8);
        $this.data.Seek(0, [System.IO.SeekOrigin]::Begin);
    }

    # add a signature at end of content - an already existing one will not be removed first
    [void] Add()
    {
        $cksum = New-Object YourFritz.Cksum;
        $this.data.Seek(0, [System.IO.SeekOrigin]::Begin);
        [byte[]] $fileData = [System.Byte[]]::CreateInstance([System.Byte], $this.data.Length);
        $this.data.Read($fileData, 0, $this.data.Length);
        $cksum.Update($fileData);
        [byte[]] $computed = $cksum.Finalize();
        $this.data.Seek(0, [System.IO.SeekOrigin]::End);
        $this.data.Write([TIcksum]::GetMagic() + $computed, 0, 8);
        $this.data.Seek(0, [System.IO.SeekOrigin]::Begin);
    }

    # replace an existing signature - use this instead of 'Add' method, if a signature is present already
    [void] Replace()
    {
        if (-not $this.HasSignature())
        {
            throw "The data stream has no TI checksum yet.";
        }
        $this.Remove();
        $this.Add();
    }

    # compare the provided $data (unsigned integer value with 32 bits, stored as LE) against the magic
    # of a TI signature
    static [bool] IsMagic([byte[]] $data)
    {
        if ($data[0] -eq 35 -and $data[1] -eq 222 -and $data[2] -eq 83 -and $data[3] -eq 196)
        {
            return $true;
        }
        return $false;
    }

    # get a buffer with TI checksum signature, ready to be written to file data
    static [byte[]] GetMagic()
    {
        return [byte[]] ( 35, 222, 83, 196 );
    }
}

#######################################################################################################
#                                                                                                     #
# class to handle hexadecimal strings                                                                 #
#                                                                                                     #
#######################################################################################################
Class HexString
{
    # convert the specified string from hexadecimal characters to its binary representation
    static [byte[]] toBytes([string] $source)
    {
        [int] $index = 0;
        [int] $value = 0;
        [bool] $odd = $false;
        [byte[]] $buffer = [byte[]]::CreateInstance([byte], $source.Length / 2);

        foreach ($char in $source.ToCharArray())
        {
            if ($odd -eq $true)
            {
                $value += [System.Convert]::ToInt32($char, 16);
                $buffer[$index] = $value;
                $index++;
                $odd = $false;
            }
            else
            {
                $value = [System.Convert]::ToInt32($char, 16) -shl 4;
                $odd = $true;
            }
        }
        if ($odd -eq $true)
        {
            throw "Odd number of digits in a hexadecimal string value.";
        }
        return $buffer;
    }

    # convert the specified binary buffer to a hexadecimal string with lower-case digits 'a' to 'f'
    static [string] toHexString([byte[]] $source)
    {
        [System.Text.StringBuilder] $output = [System.Text.StringBuilder]::new();

        foreach ($byte in $source)
        {
            $output.Append([String]::Format("{0:x2}", $byte));
        }
        return $output.ToString();
    }

    # convert the specified binary buffer to a hexadecimal string with upper-case digits 'A' to 'F'
    static [string] toHexStringUpcase([byte[]] $source)
    {
        [System.Text.StringBuilder] $output = [System.Text.StringBuilder]::new();

        foreach ($byte in $source)
        {
            $output.Append([String]::Format("{0:X2}", $byte));
        }
        return $output.ToString();
    }
}

#######################################################################################################
#                                                                                                     #
# relevant ASN.1 data type encodings                                                                  #
#                                                                                                     #
#######################################################################################################
Enum Asn1Type
{
    Boolean = 1;
    Int = 2;
    BitString = 3;
    OctetString = 4;
    NULL = 5;
    OID = 6;
    Utf8String = 12;
    Sequence = 48;
    Set = 49;
}

#######################################################################################################
#                                                                                                     #
# ASN.1 object identifier encoding/decoding                                                           #
#                                                                                                     #
#######################################################################################################
Class Asn1OID
{
    [Asn1Data] $data;

    # create an instance from an ASN.1 encoded object ID
    Asn1OID([Asn1Data] $data)
    {
        $this.data = $data;
    }

    # get the string representation of the contained OID (with periods between each level)
    [string] ToString()
    {
        [System.Text.StringBuilder] $output = [System.Text.StringBuilder]::new();
        foreach ($value in $this.ToIntArray())
        {
            if ($output.Length -gt 0)
            {
                $output.Append(".");
            }
            $output.Append($value.ToString());
        }
        return $output.ToString();
    }

    # get an integer array with all levels of the contained OID
    [int[]] ToIntArray()
    {
        [int[]] $output = $null;
        [int] $value = 0;
        [bool] $multiByte = $false;
        foreach ($byte in $this.data.value)
        {
            if ($output.Count -eq 0)
            {
                $output += ($byte - ($byte % 40)) / 40; # PS tries to round here, so we remove the remainings
                $output += $byte % 40;
            }
            else
            {
                if ($byte -ge 128)
                {
                    # multi-byte encoded and not the last byte
                    $byte = $byte -band 127; # remove highest bit
                    $value = ($value + [int] $byte) -shl 7; # 7 significant bits per byte
                    $multiByte = $true;
                }
                else
                {
                    if ($multiByte -eq $true)
                    {
                        # last byte of a multi-byte value
                        $value += [int] $byte; # add right-most byte
                        $multiByte = $false;
                    }
                    else
                    {
                        # single byte value
                        $value = [int] $byte;
                    }
                    $output += $value; # append it to array
                    $value = 0;
                }
            }
        }
        return $output;
    }

    # create a new instance from an integer array with the complete value chain
    static [Asn1OID] fromOID([int[]] $oids)
    {
        [int] $index = 0;
        [byte[]] $value = 0;
        foreach ($tupel in $oids)
        {
            if ($index -lt 2)
            {
                $value[0] = $value[0] * 40 + $tupel;
            }
            else
            {
                if ($tupel -le 127)
                {
                    # single byte encoding
                    $value += [byte] $tupel;
                }
                else
                {
                    # multi-byte encoding of values > 127
                    [int] $bytes = 0;
                    [int] $val = $tupel;
                    [int] $highBit = 128;
                    while ($val -gt 0)
                    {
                        $val = $val -shr 7;
                        $bytes++;
                    }
                    while ($bytes -gt 0)
                    {
                        $val = ($tupel -shr (($bytes - 1) * 7)) -band 127;
                        if ($bytes -eq 1)
                        {
                            $highBit = 0;
                        }
                        $value += ($val + $highBit);
                        $bytes--;
                    }
                }
            }
            $index++;
        }
        [byte[]] $type = [byte] [Asn1Type]::OID, $value.Count;
        return [Asn1OID]::new([Asn1Data]::new($type + $value));
    }

    # create a new instance from the specified strings, representing each single level of the final OID
    static [Asn1OID] fromOID([string[]] $oids)
    {
        [int[]] $intOIDs = [int[]]::CreateInstance([int], $oids.Count);
        [int] $index = 0;
        for ([int] $i = 0; $i -lt $oids.Count; $i++)
        {
            $intOIDs[$index] = [System.Convert]::ToInt32($oids[$i]);
            $index++;
        }
        return [Asn1OID]::fromOID($intOIDs);
    }

    # create a new instance from the specified OID string (numbers with periods in-between)
    static [Asn1OID] fromOID([string] $oid)
    {
        [string[]] $oids = $oid.Split(".");
        return [Asn1OID]::fromOID($oids);
    }
}

#######################################################################################################
#                                                                                                     #
# class to handle ASN.1 encoded data (with very limited capabilities, needed for private and public   #
# RSA key files from OpenSSL)                                                                         #
#                                                                                                     #
#######################################################################################################
Class Asn1Data
{
    [Asn1Type] $dataType;
    [int] $dataSize;
    [byte[]] $value;
    [int] $encodedSize;
    [int] $unusedBitStringBits;
    [bool] $unsigned;

    # create a new instance from an existing one
    Asn1Data([Asn1Data] $data)
    {
        $this.dataType = $data.dataType;
        $this.dataSize = $data.dataSize;
        $this.encodedSize = $data.encodedSize;
        $this.unusedBitStringBits = $data.unusedBitStringBits;
        $this.unsigned = $data.unsigned;
        $this.value = [byte[]]::CreateInstance([byte], $data.value.Count);
        [System.Array]::Copy($data.value, $this.value, $data.value.Count);
    }

    # create a new instance from a byte stream in DER encoding
    Asn1Data([byte[]] $data)
    {
        $this.dataType = [Asn1Type] $data[0];
        $this.dataSize = $data[1];

        [int] $offset = 2;
        [int] $bitStringOffset = 0;

        if (($data[1] -band 128) -ne 0)
        {
            # explicit length encoding follows
            $this.dataSize = 0;

            for ([int] $i = 0; $i -lt ($data[1] -band 127); $i++)
            {
                $this.dataSize = ($this.dataSize -shl 8) + [System.Convert]::ToInt32($data[2 + $i]);
                $offset++;
            }
        }

        if ($this.dataType -eq [Asn1Type]::BitString -or $this.dataType -eq [Asn1Type]::Int)
        {
            if ($this.dataType -eq [Asn1Type]::BitString)
            {
                $this.unusedBitStringBits = $data[$offset];
                $bitStringOffset = 1;
            }
            else
            {
                if ($data[$offset] -eq 0 -and $this.dataSize -gt 1)
                {
                    # skip additional NUL byte for unsigned integers with high order bit set
                    $bitStringOffset = 1;
                    $this.unsigned = $true;
                }
            }
        }

        [byte[]] $this.value = [byte[]]::CreateInstance([byte], $this.dataSize - $bitStringOffset);
        $this.encodedSize = $this.dataSize + $offset;
        [System.Array]::Copy($data, $offset + $bitStringOffset, $this.value, 0, $this.dataSize - $bitStringOffset);
    }

    # create a new integer value, which may contain signed or unsigned data
    # if data is unsigned per definition and the high order bit of value is set, an addition NUL
    # byte is added in front to ensure, that the high order bit of first byte is not set anymore
    Asn1Data([Asn1Type] $dataType, [byte[]] $value, [bool] $unsigned)
    {
        if ($dataType -ne [Asn1Type]::Int)
        {
            throw "This constructor is only valid for ASN.1 integer values.";
        }
        $this.Initialize($dataType, $value, $unsigned);
    }

    # create any new value, integers are always unsigned here
    Asn1Data([Asn1Type] $dataType, [byte[]] $value)
    {
        $this.Initialize($dataType, $value, $true);
    }

    # set instance properties accordingly for different type(s) and content
    hidden [void] Initialize([Asn1Type] $dataType, [byte[]] $value, [bool] $unsigned)
    {
        $this.dataType = $dataType;
        $this.dataSize = $value.Count;

        switch ($dataType)
        {
            BitString { $this.unusedBitStringBits = 0; $this.dataSize++; break; }
            Int { $this.unsigned = $unsigned; if ($value[0] -gt 127) { $this.dataSize++; }; break; }
        }

        $this.value = $value;
        $this.encodedSize = $this.dataSize + 2;

        if ($this.dataSize -gt 127)
        {
            [int] $shift = 0;

            while ($this.dataSize -shr ($shift -shl 3))
            {
                $this.encodedSize++;
                $shift++;
            }
        }
    }

    # get a new OID instance (which provides methods to handle ASN.1 object ID values) from this instance
    [Asn1OID] oid()
    {
        if ($this.dataType -ne [Asn1Type]::OID)
        {
            throw "Data inside ASN.1 structure isn't an object identifier.";
        }
        return [Asn1OID]::new($this);
    }

    # get the members of a 'sequence' as an array of Asn1Data objects
    [Asn1Data[]] seq()
    {
        if ($this.dataType -ne [Asn1Type]::Sequence)
        {
            throw "Data inside ASN.1 structure isn't a sequence.";
        }

        [Asn1Data[]] $output = $null;
        [int] $sequenceSize = $this.dataSize;
        [int] $offset = 0;
        [byte[]] $seqArray = $null;

        while ($sequenceSize -gt 0)
        {
            $seqArray = [byte[]]::CreateInstance([byte], $sequenceSize);
            [System.Array]::Copy($this.value, $offset, $seqArray, 0, $sequenceSize);
            [Asn1Data] $val = [Asn1Data]::new($seqArray);
            $output += $val;
            $sequenceSize -= $val.encodedSize;
            $offset += $val.encodedSize;
        }
        return $output;
    }

    # type-safe extractor for 'Bit String' data, throws an exception, if used with other data types
    [Asn1Data] bitString()
    {
        if ($this.dataType -ne [Asn1Type]::BitString)
        {
            throw "Data inside ASN.1 structure isn't a bit string.";
        }
        return [Asn1Data]::new($this);
    }

    # type-safe extractor for 'int' data, throws an exception, if used with other data types
    [byte[]] getIntValue()
    {
        if ($this.dataType -ne [Asn1Type]::Int)
        {
            throw "Data inside ASN.1 structure isn't an integer value.";
        }
        return $this.value;
    }

    # type-safe extractor for 'int' data, throws an exception, if used with other data types
    [byte[]] getIntValue([int] $digits)
    {
        if ($this.dataType -ne [Asn1Type]::Int)
        {
            throw "Data inside ASN.1 structure isn't an integer value.";
        }
        return [System.Byte[]]::CreateInstance([System.Byte], [Math]::Max(0, $digits - $this.value.Count)) + $this.value;
    }

    # get the DER encoded content of this instance
    [byte[]] toByteArray()
    {
        [byte[]] $output = [byte[]]::CreateInstance([byte], $this.encodedSize);
        [int] $offset = 1;
        [int] $outputSize = $this.dataSize;

        $output[0] = $this.dataType;

        if ($this.dataSize -gt 127)
        {
            [int] $sizeSize = 0;

            while ((($this.dataSize -shr ($sizeSize -shl 3)) -band 255) -ne 0)
            {
                $sizeSize++;
            }
            $output[$offset] = $sizeSize -bor 128;
            $offset++;

            while ($sizeSize -gt 0)
            {
                $sizeSize--;
                $output[$offset] = ($this.dataSize -shr ($sizeSize -shl 3)) -band 255;
                $offset++;
            }
        }
        else
        {
            $output[$offset] = [System.Convert]::ToByte($this.dataSize);
            $offset++;
        }

        switch ($this.dataType)
        {
            BitString { $output[$offset] = $this.unusedBitStringBits; $offset++; $outputSize--; break; }
            Int { if ($this.value[0] -gt 127 -and $this.unsigned) { $output[$offset] = 0; $offset++; $outputSize--; break; } }
        }

        if ($outputSize -gt 0)
        {
            [System.Array]::Copy($this.value, 0, $output, $offset, $outputSize);
        }

        return $output;
    }
}

#######################################################################################################
#                                                                                                     #
# class to derive a key for private key encryption/decryption from a password and a salt value        #
#                                                                                                     #
# - should implement PBKDF1 (RFC 2828), but ...                                                       #
#                                                                                                     #
# - due to OpenSSL' weakness of key derivation for private key encryption (only 1 hashing round and   #
#   if no key IV output is needed, then no key stretching is required), this is simply a MD5 hash of  #
#   the password string, concatenated with the first 8 bytes of the specified salt value - that's all #
#   for AES-128 encryption                                                                            #
#                                                                                                     #
#######################################################################################################
Class BytesToKey
{
    # derive a simple AES encryption key from the specified $password and (the first 8 bytes of) a
    # specified $salt value
    static [byte[]] GetBytes([string] $password, [byte[]] $salt)
    {
        [byte[]] $pepper = [byte[]]::CreateInstance([byte], 8);
        [System.Array]::Copy($salt, 0, $pepper, 0, 8);
        [byte[]] $key = [System.Text.Encoding]::ASCII.GetBytes($password) + $pepper;
        [System.Security.Cryptography.MD5CryptoServiceProvider] $md5 = [System.Security.Cryptography.MD5CryptoServiceProvider]::new();
        return $md5.ComputeHash($key);
    }
}

#######################################################################################################
#                                                                                                     #
# class to handle key files for signing and signature verification                                    #
#                                                                                                     #
# - it may create, load and store RSA keys (with private info or only public data) in various formats #
# - only RSA keys with 1024 bits are supported here                                                   #
# - PowerShell Core 6.0 uses (via OpenSSL) a default key size of 2048 bits, we have to reset this     #
# - any data file in PEM or DER format is compatible with OpenSSL 1.0 and 1.1 implementations         #
#                                                                                                     #
#######################################################################################################
Class SigningKey
{
    [System.Security.Cryptography.RSA] $rsa;

    # create a new instance with a freshly generated key
    SigningKey()
    {
        $this.rsa = [System.Security.Cryptography.RSA]::Create();
        $this.rsa.KeySize = 1024;
    }

    # create a new instance from an existing key object (ex- and import the key components -> deep copy)
    SigningKey([SigningKey] $sourceKey)
    {
        $this.rsa = [System.Security.Cryptography.RSA]::Create();
        $this.rsa.ImportParameters($sourceKey.rsa.ExportParameters(-not $sourceKey.rsa.PublicOnly));
    }

    # create a new instance from an existing key object, copy only public parts, of requested
    SigningKey([SigningKey] $source, [bool] $onlyPublicData)
    {
        $this.rsa = [System.Security.Cryptography.RSA]::Create();
        # throws an exception, if $onlyPublicData is $true and the source key has only public parts
        $this.rsa.ImportParameters($source.rsa.ExportParameters(-not $onlyPublicData));
    }

    # create a new instance from the specified XML string (.NET framework native export format, without
    # further protection)
    SigningKey([string] $xmlFormattedKey)
    {
        $this.rsa = [System.Security.Cryptography.RSA]::Create();
        $this.rsa.FromXmlString($xmlFormattedKey);
    }

    # create a new instance from the specified parameters structure
    SigningKey([System.Security.Cryptography.RSAParameters] $rsaParameters)
    {
        $this.rsa = [System.Security.Cryptography.RSA]::Create();
        $this.rsa.ImportParameters($rsaParameters);
    }

    # get only the public 'modulus' component from the contained key, string will be of length 256
    [string] toAVMModulus()
    {
        return [HexString]::toHexString($this.rsa.ExportParameters($false).Modulus);
    }

    # get a XML string from the contained key material
    [string] toXmlString([bool] $withPrivateData)
    {
        return $this.rsa.ToXmlString($withPrivateData);
    }

    # get public key data in AVM's format (two lines of hexadecimal text with modulus and exponent)
    [System.IO.MemoryStream] toASCStream()
    {
        [System.Security.Cryptography.RSAParameters] $rsaParameters = $this.rsa.ExportParameters($false);
        [string] $modulus = [HexString]::toHexString($rsaParameters.Modulus);
        [string] $exponent = [HexString]::toHexString($rsaParameters.Exponent);

        [string] $modulus_unsigned = [System.String]::Empty;
        [string] $exponent_unsigned = [System.String]::Empty;

        if ($rsaParameters.Modulus[0] -gt 127)
        {
            $modulus_unsigned = "00";
        }

        if ($rsaParameters.Exponent[0] -gt 127)
        {
            $exponent_unsigned = "00";
        }

        [byte[]] $asciiText = [System.Text.Encoding]::ASCII.GetBytes($modulus_unsigned + $modulus + "`n" + $exponent_unsigned + $exponent + "`n");

        return [System.IO.MemoryStream]::new($asciiText);
    }

    # save the contained public key to file $fileName in AVM's format
    [void] toASCFile([string] $fileName)
    {
        [System.IO.File]::WriteAllBytes($fileName, $this.toASCStream().ToArray());
    }

    # get DER sequence of public key components (RFC 2313)
    hidden [byte[]] toDER_public()
    {
        [System.Security.Cryptography.RSAParameters] $rsaParameters = $this.rsa.ExportParameters($false);

        [Asn1Data] $modulus = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.Modulus);
        [Asn1Data] $exponent = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.Exponent);
        [Asn1Data] $factSeq = [Asn1Data]::new([Asn1Type]::Sequence, $modulus.ToByteArray() + $exponent.toByteArray());
        [Asn1Data] $keyBits = [Asn1Data]::new([Asn1Type]::BitString, $factSeq.toByteArray());

        [Asn1Data] $rsaOID = [Asn1OID]::fromOID("1.2.840.113549.1.1.1").data;
        [Asn1Data] $oidSeq = [Asn1Data]::new([Asn1Type]::Sequence, $rsaOID.toByteArray() + [Asn1Data]::new([Asn1Type]::NULL, $null).toByteArray());

        [Asn1Data] $complete = [Asn1Data]::new([Asn1Type]::Sequence, $oidSeq.toByteArray() + $keyBits.toByteArray());

        return $complete.toByteArray();
    }

    # get DER sequence with private key components (RFC 2313)
    hidden [byte[]] toDER_private()
    {
        [System.Security.Cryptography.RSAParameters] $rsaParameters = $this.rsa.ExportParameters($true);

        [Asn1Data] $version = [Asn1Data]::new([Asn1Type]::Int, [byte[]] (0));
        [Asn1Data] $modulus = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.Modulus);
        [Asn1Data] $exponent = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.Exponent);
        [Asn1Data] $d = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.D);
        [Asn1Data] $p = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.P);
        [Asn1Data] $q = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.Q);
        [Asn1Data] $dp = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.DP);
        [Asn1Data] $dq = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.DQ);
        [Asn1Data] $iq = [Asn1Data]::new([Asn1Type]::Int, $rsaParameters.InverseQ);

        [Asn1Data] $keySeq = [Asn1Data]::new([Asn1Type]::Sequence,
            $version.toByteArray() +
            $modulus.toByteArray() +
            $exponent.toByteArray() +
            $d.toByteArray() +
            $p.toByteArray() +
            $q.toByteArray() +
            $dp.toByteArray() +
            $dq.toByteArray() +
            $iq.toByteArray()
        );

        return $keySeq.toByteArray();
    }

    # get DER bytes for private or public parts
    [byte[]] toDER([bool] $withPrivateData)
    {
        if ($withPrivateData)
        {
            return $this.toDER_private();
        }
        else
        {
            return $this.toDER_public();
        }
    }

    # get a stream based on 'toDER' method output
    [System.IO.MemoryStream] toDERStream([bool] $withPrivateData)
    {
        return [System.IO.MemoryStream]::new($this.toDER($withPrivateData));
    }

    # save the stream from 'toDERStream' to file $outputFileName
    [void] toDERFile([bool] $withPrivateData, [string] $outputFileName)
    {
        $this.toDERStream($withPrivateData).WriteTo([System.IO.File]::Create($outputFileName));
    }

    # get an array containing the public key parts in PEM format
    [byte[]] toRSAPublicKey()
    {
        [System.IO.StringWriter] $writer = [System.IO.StringWriter]::new();
        $writer.NewLine = "`n";

        $writer.WriteLine("-----BEGIN PUBLIC KEY-----");

        [System.Text.StringBuilder] $pemString = [System.Text.StringBuilder]::new([System.Convert]::ToBase64String($this.toDER($false)));
        for ([int] $offset = 0; $offset -lt $pemString.Length; $offset += 64)
        {
            [int] $size = [Math]::Min($pemString.Length - $offset, 64);
            $writer.WriteLine($pemString.ToString($offset, $size));
        }

        $writer.WriteLine("-----END PUBLIC KEY-----");

        return [System.Text.Encoding]::ASCII.GetBytes($writer.ToString());
    }

    # get a stream from 'toRSAPublicKey' array output
    [System.IO.MemoryStream] toRSAPublicKeyStream()
    {
        return [System.IO.MemoryStream]::new($this.toRSAPublicKey());
    }

    # save stream from 'toRSAPublicKeyStream' to file $outputFileName
    [void] toRSAPublicKeyFile([string] $outputFileName)
    {
        $this.toRSAPublicKeyStream().WriteTo([System.IO.File]::Create($outputFileName));
    }

    # get an array containing the private key in PEM format, optionally encrypted and with
    # $password protected
    [byte[]] toRSAPrivateKey([string] $keyPassword)
    {
        [byte[]] $derKey = $this.toDER($true);

        [System.IO.StringWriter] $writer = [System.IO.StringWriter]::new();
        $writer.NewLine = "`n";

        $writer.WriteLine("-----BEGIN RSA PRIVATE KEY-----");

        if ($keyPassword.Length -gt 0)
        {
            [System.Security.Cryptography.AesManaged] $aes = [System.Security.Cryptography.AesManaged]::new();
            [System.Security.Cryptography.RNGCryptoServiceProvider] $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new([byte[]]$null);

            $aes.KeySize = 128;
            $aes.BlockSize = 128;
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC;
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7;

            [byte[]] $salt = [byte[]]::CreateInstance([byte], $aes.IV.Length);
            $rng.GetBytes($salt);
            [byte[]] $key = [BytesToKey]::GetBytes($keyPassword, $salt);

            [System.Security.Cryptography.ICryptoTransform] $encryptor = $aes.CreateEncryptor($key, $salt);
            $key = $null;
            $derKey = $encryptor.TransformFinalBlock($derKey, 0, $derKey.Count);
            $encryptor.Dispose();
            $aes.Clear();

            [string] $saltString = [HexString]::toHexStringUpcase($salt);
            $writer.WriteLine("Proc-Type: 4,ENCRYPTED");
            $writer.WriteLine("DEK-Info: AES-128-CBC,$saltstring")
            $writer.WriteLine();
        }

        [System.Text.StringBuilder] $pemString = [System.Text.StringBuilder]::new([System.Convert]::ToBase64String($derKey));
        for ([int] $offset = 0; $offset -lt $pemString.Length; $offset += 64)
        {
            [int] $size = [Math]::Min($pemString.Length - $offset, 64);
            $writer.WriteLine($pemString.ToString($offset, $size));
        }

        $writer.WriteLine("-----END RSA PRIVATE KEY-----");

        return [System.Text.Encoding]::ASCII.GetBytes($writer.ToString());
    }

    # get a stream from 'toRSAPrivateKey' output array
    [System.IO.MemoryStream] toRSAPrivateKeyStream([string] $keyPassword)
    {
        return [System.IO.MemoryStream]::new($this.toRSAPrivateKey($keyPassword));
    }

    # save the outcome of 'toRSAPrivateKeyStream' to file $outputFileName
    [void] toRSAPrivateKeyFile([string] $outputFileName, [string] $keyPassword)
    {
        $this.toRSAPrivateKeyStream($keyPassword).WriteTo([System.IO.File]::Create($outputFileName));
    }

    # read a text file containing modulus and exponent as hexadecimal string (AVM's public key file format)
    static [SigningKey] FromASCFile([string] $fileName)
    {
        [int] $index = 0;
        [System.Security.Cryptography.RSAParameters] $rsaParameters = New-Object System.Security.Cryptography.RSAParameters;

        foreach ($line in [System.IO.File]::ReadLines($fileName, [System.Text.Encoding]::ASCII))
        {
            if ($index -eq 0)
            {
                if ($line.Substring(0, 2) -eq "00")
                {
                    $line = $line.Substring(2);
                }
                $rsaParameters.Modulus = [HexString]::toBytes($line);
            }
            else
            {
                if ($index -eq 1)
                {
                    $rsaParameters.Exponent = [HexString]::toBytes($line);
                }
                else
                {
                    throw "Invalid ASC file format.";
                }
            }
            $index++;
        }

        return [SigningKey]::new($rsaParameters);
    }

    # read a RSA private key file (unencrypted) with Base64 encoded PKCS1.5 structure
    static [SigningKey] FromRSAPrivateKeyFile([string] $fileName)
    {
        return [SigningKey]::FromRSAPrivateKeyFile($fileName, [System.String]::Empty);
    }

    # read a RSA private key file (optionally encrypted) with Base64 encoded PKCS#1 (1.5 / RFC 2313) structure
    static [SigningKey] FromRSAPrivateKeyFile([string] $fileName, [string] $keyPassword)
    {
        [int] $index = 0;
        [string[]] $lines = Get-Content $fileName;
        [byte[]] $rsaPKey = $null;

        if ($lines[$lines.GetLowerBound(0)].CompareTo("-----BEGIN RSA PRIVATE KEY-----") -ne 0 -or
            $lines[$lines.GetUpperBound(0)].CompareTo("-----END RSA PRIVATE KEY-----") -ne 0)
        {
            throw "PEM file doesn't contain RSA private key data.";
        }

        if ($lines[$lines.GetLowerBound(0) + 1].Contains(":"))
        {
            # - looks like "Proc-Type" and "DEK-Info" are present, we only support AES-128 encryption yet
            # - the (usually two) header lines are terminated by an empty line as delimiter in front of the
            #   Base64 encoded content - see RFC 1421 for further info
            [string] $procTypeLine = $lines[$lines.GetLowerBound(0) + 1];
            [string] $dekInfoLine = $lines[$lines.GetLowerBound(0) + 2];
            [string] $endOfHeaderLine = $lines[$lines.GetLowerBound(0) + 3];

            if ($procTypeLine.CompareTo("Proc-Type: 4,ENCRYPTED") -ne 0 -or
                -not $dekInfoLine.StartsWith("DEK-Info: AES-128-CBC,") -or
                $endOfHeaderLine.Length -ne 0)
            {
                throw "Unexpected content in encrypted RSA private key file.";
            }

            [byte[]] $salt = [HexString]::toBytes($dekInfoLine.Substring($dekInfoLine.IndexOf(",") + 1));
            if ($keyPassword.Length -eq 0)
            {
                throw "Missing password for encrypted private key file.";
            }

            [string] $content = [System.String]::Empty;
            foreach ($line in $lines)
            {
                if ($index -gt ($lines.GetLowerBound(0) + 3) -and
                    $index -ne $lines.GetUpperBound(0))
                {
                    $content += $line;
                }
                $index++;
            }
            $content = $content.Trim();
            $rsaPKey = [System.Convert]::FromBase64String($content);

            [byte[]] $key = [BytesToKey]::GetBytes($keyPassword, $salt);
            [System.Security.Cryptography.AesManaged] $aes = [System.Security.Cryptography.AesManaged]::new();
            $aes.KeySize = 128;
            $aes.BlockSize = 128;
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC;
            $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7;
            [System.Security.Cryptography.ICryptoTransform] $decryptor = $aes.CreateDecryptor($key, $salt);
            $key = $null;

            try
            {
                $rsaPKey = $decryptor.TransformFinalBlock($rsaPKey, 0, $rsaPKey.Count);
            }
            catch [System.Security.Cryptography.CryptographicException]
            {
                throw "The specified password seems to be wrong.";
            }

            $decryptor.Dispose();
            $aes.Clear();

            if ($rsaPKey[0] -ne [byte] [Asn1Type]::Sequence)
            {
                throw "Invalid private key file data after decryption.";
            }
        }
        else
        {
            [string] $content = [System.String]::Empty;

            foreach ($line in $lines)
            {
                if ($index -ne $lines.GetLowerBound(0) -and
                    $index -ne $lines.GetUpperBound(0))
                {
                    $content += $line;
                }
                $index++;
            }

            $content = $content.Trim();
            $rsaPKey = [System.Convert]::FromBase64String($content);
        }
        return [SigningKey]::FromRSAPrivateKeyDER($rsaPKey);
    }

    # read a PKCS#1 (1.5 / RFC 2313) formatted public key with Base64 encoding
    static [SigningKey] FromRSAPublicKeyFile([string] $fileName)
    {
        [string[]] $lines = Get-Content $fileName;
        [int] $index = 0;

        if ($lines[$lines.GetLowerBound(0)].CompareTo("-----BEGIN PUBLIC KEY-----") -ne 0 -or
            $lines[$lines.GetUpperBound(0)].CompareTo("-----END PUBLIC KEY-----") -ne 0)
        {
            throw "PEM file doesn't contain RSA public key data.";
        }

        [string] $content = [System.String]::Empty;
        foreach ($line in $lines)
        {
            if ($index -ne $lines.GetLowerBound(0) -and
                $index -ne $lines.GetUpperBound(0))
            {
                $content += $line;
            }
            $index++;
        }
        $content = $content.Trim();

        return [SigningKey]::FromRSAPublicKeyDER([System.Convert]::FromBase64String($content));
    }

    # check, if the ASN.1 formatted data contains a public key (with proper OID for "rsaPublicKey")
    # don't throw an exception on errors
    static [bool] IsRSAPublicKey([byte[]] $data)
    {
        [Asn1Data] $asnData = [Asn1Data]::new($data);
        if ($asnData.dataType -ne [Asn1Type]::Sequence)
        {
            return $false;
        }

        [Asn1Data[]] $innerData = $asnData.seq();
        if ($innerData.Count -ne 2 -or $innerData[0].dataType -ne [Asn1Type]::Sequence -or $innerData[1].dataType -ne [Asn1Type]::BitString)
        {
            return $false;
        }

        [Asn1Data[]] $oidSeq = $innerData[0].seq();
        if ($oidSeq.Count -ne 2 -or $oidSeq[0].dataType -ne [Asn1Type]::OID -or $oidSeq[1].dataType -ne [Asn1Type]::NULL)
        {
            return $false;
        }

        [Asn1OID] $oid = $oidSeq[0].oid();
        [string] $oidString = $oid.ToString();
        if ($oidString.CompareTo("1.2.840.113549.1.1.1") -ne 0)
        {
            return $false;
        }

        [Asn1Data] $keySeq = [Asn1Data]::new($innerData[1].bitString().value);
        if ($keySeq.dataType -ne [Asn1Type]::Sequence)
        {
            return $false;
        }

        [Asn1Data[]] $keyValues = $keySeq.seq();
        if ($keyValues.Count -ne 2)
        {
            return $false;
        }
        if ($keyValues[0].dataType -ne [Asn1Type]::Int -or $keyValues[1].dataType -ne [Asn1Type]::Int)
        {
            return $false;
        }

        return $true;
    }

    # create a RSA private key from DER data
    static [SigningKey] FromRSAPrivateKeyDER([byte[]] $data)
    {
        [Asn1Data] $rsaPrivateKey = [Asn1Data]::new($data);

        # expected is a sequence containing nine (9) integer values
        # look at RFC 2313, point 7.2 - RSAPrivateKey sequence
        if ($rsaPrivateKey.dataType -ne [Asn1Type]::Sequence)
        {
            throw "Invalid private key file data (not a sequence at all for RSAPrivateKey).";
        }
        [Asn1Data[]] $keyValues = $rsaPrivateKey.seq();

        if ($keyValues.Count -ne 9)
        {
            throw "Invalid private key file data (invalid number of entries for RSAPrivateKey).";
        }
        foreach ($keyEntry in $keyValues)
        {
            if ($keyEntry.dataType -ne [Asn1Type]::Int)
            {
                throw "Invalid private key file data (RSAPrivateKey sequence contains only 'int' entries).";
            }
        }
        if ($keyValues[0].value -ne 0)
        {
            throw "Invalid private key file data (version entry from RSAPrivateKey has to be zero).";
        }

        [System.Security.Cryptography.RSAParameters] $rsaParameters = New-Object System.Security.Cryptography.RSAParameters;
        $rsaParameters.Modulus = $keyValues[1].getIntValue(128);
        $rsaParameters.Exponent = $keyValues[2].getIntValue();
        $rsaParameters.D = $keyValues[3].getIntValue(128);
        $rsaParameters.P = $keyValues[4].getIntValue(64);
        $rsaParameters.Q = $keyValues[5].getIntValue(64);
        $rsaParameters.DP = $keyValues[6].getIntValue(64);
        $rsaParameters.DQ = $keyValues[7].getIntValue(64);
        $rsaParameters.InverseQ = $keyValues[8].getIntValue(64);

        # fast cleanup for private data - but garbage collection is a task of our host
        $keyEntry = $null;
        $keyValues = $null;
        $rsaPrivateKey = $null;

        return [SigningKey]::new($rsaParameters);
    }

    # create a public key from DER data
    static [SigningKey] FromRSAPublicKeyDER([byte[]] $data)
    {
        [Asn1Data] $asnData = [Asn1Data]::new($data);
        if ($asnData.dataType -ne [Asn1Type]::Sequence)
        {
            throw "Invalid public key file data (not a sequence at all).";
        }

        # expected are
        # - one more sequence with the OID of "rsaPublicKey" and
        # - a bit string containing a sequence of two integers (modulus and exponent)
        [Asn1Data[]] $innerData = $asnData.seq();
        if ($innerData.Count -ne 2 -or $innerData[0].dataType -ne [Asn1Type]::Sequence -or $innerData[1].dataType -ne [Asn1Type]::BitString)
        {
            throw "Invalid public key file data (first sequence has to contain another sequence and a bit-string value).";
        }
        [Asn1Data[]] $oidSeq = $innerData[0].seq();

        # expected are
        # - an OID of "rsaEncryption" and
        # - a NULL entry
        if ($oidSeq.Count -ne 2 -or $oidSeq[0].dataType -ne [Asn1Type]::OID -or $oidSeq[1].dataType -ne [Asn1Type]::NULL)
        {
            throw "Invalid public key file data (OID sequence has to contain an OID and a NULL entry).";
        }
        [Asn1OID] $oid = $oidSeq[0].oid();
        [string] $oidString = $oid.ToString();

        # expected is the OID of "rsaEncryption"
        if ($oidString.CompareTo("1.2.840.113549.1.1.1") -ne 0)
        {
            throw "Invalid public key file data - OID $oidString isn't 'rsaEncryption'.";
        }
        [Asn1Data] $keySeq = [Asn1Data]::new($innerData[1].bitString().value);

        # expected is a bit string containing one more sequence with two integer values
        # look at RFC 2313, point 7.1 - RSAPublicKey sequence
        if ($keySeq.dataType -ne [Asn1Type]::Sequence)
        {
            throw "Invalid public key file data (the bit strings doesn't contain another sequence for RSAPublicKey).";
        }
        [Asn1Data[]] $keyValues = $keySeq.seq();

        if ($keyValues.Count -ne 2)
        {
            throw "Invalid public key file data (invalid number of key sequence entries).";
        }
        if ($keyValues[0].dataType -ne [Asn1Type]::Int -or $keyValues[1].dataType -ne [Asn1Type]::Int)
        {
            throw "Invalid public key file data (key sequence entries have to be of type 'int').";
        }

        [System.Security.Cryptography.RSAParameters] $rsaParameters = New-Object System.Security.Cryptography.RSAParameters;
        $rsaParameters.Modulus = $keyValues[0].value;
        $rsaParameters.Exponent = $keyValues[1].value;

        return [SigningKey]::new($rsaParameters);
    }

    # create a RSA key from a DER file with known content
    static [SigningKey] FromDERFile([string] $fileName, [bool] $isPublicKey)
    {
        if ($isPublicKey)
        {
            return [SigningKey]::FromRSAPublicKeyDER([System.IO.File]::ReadAllBytes($fileName));
        }
        else
        {
            return [SigningKey]::FromRSAPrivateKeyDER([System.IO.File]::ReadAllBytes($fileName));
        }
    }

    # create a RSA key from a DER file with unknown content
    static [SigningKey] FromDERFile([string] $fileName)
    {
        [bool] $isPublicKey = [SigningKey]::IsRSAPublicKey([System.IO.File]::ReadAllBytes($fileName));
        return [SigningKey]::FromDERFile($fileName, $isPublicKey);
    }
}

#######################################################################################################
#                                                                                                     #
# derived class for a TAR file, with additional/optional handling (only removal) of TI checksums      #
# on extraction and the ability to verify a signature or create and append a signature                #
#                                                                                                     #
#######################################################################################################
Class FirmwareImage : TarFile
{
    [string] $imageName;
    [TarMember] $signature;
    [bool] $isSigned;

    # create an empty image
    FirmwareImage() : base()
    {
        $this.isSigned = $false;
    }

    # create an image based on $filename
    FirmwareImage([string] $fileName) : base($fileName)
    {
        $this.imageName = $fileName;
        $this.isSigned = $this.findSignature();
    }

    # replace current content (in memory) with data from $filename, may be used to "re-open" a file, too
    [void] Open([string] $fileName)
    {
        $this.imageName = $fileName;
        ([TarFile]$this).loadTarFile([System.IO.File]::OpenRead($fileName));
        $this.isSigned = $this.findSignature();
    }

    # save the current content to the original file (unsafe, there's no backup of the old content)
    [void] Save()
    {
        if ($this.imageName -eq $null -or $this.imageName.Length -eq 0)
        {
            throw "Missing file name of this firmware image.";
        }
        $this.SaveTo($this.ImageName);
        [System.IO.File]::WriteAllBytes($this.imageName, $this.data.ToArray());
    }

    # save the current content to the original file (unsafe, there's no backup of the old content)
    [void] SaveTo([string] $outputFileName)
    {
        [System.IO.File]::WriteAllBytes($outputFileName, $this.data.ToArray());
    }

    # get the specified member data after removing the TI checksum, if any
    [System.IO.MemoryStream] extractMemberAndRemoveChecksum([TarMember] $member)
    {
        # we need a new stream or our changes will affect the original member data
        [System.IO.MemoryStream] $memberStream = [System.IO.MemoryStream]::new($member.data.ToArray());
        [TIcksum] $cksum = [TIcksum]::new($memberStream);
        if ($cksum.HasSignature())
        {
            $cksum.Remove();
        }
        $memberStream.Seek(0, [System.IO.SeekOrigin]::Begin);
        return $memberStream;
    }

    # get the specified member data after removing the TI checksum, if any - save data to $outputName
    [void] extractMemberAndRemoveChecksum([TarMember] $member, [string] $outputName)
    {
        $this.extractMemberAndRemoveChecksum($member).WriteTo([System.IO.File]::Create($outputName));
    }

    # verify the current signature with the specified public key, which was loaded from somewhere else
    [bool] verifySignature([SigningKey[]] $keys)
    {
        [byte[]] $sigBytes = $this.extractMember($this.signature).ToArray();
        foreach ($key in $keys)
        {
            try
            {
                [bool] $verify = $key.rsa.VerifyData($this.signingStream(), $sigBytes, "MD5", [System.Security.Cryptography.RSASignaturePadding]::Pkcs1);
                if ($verify)
                {
                    return $true;
                }
            }
            catch [System.Security.Cryptography.CryptographicException]
            {
                continue;
            }
            catch
            {
                throw ("Error verifying signed data.$([System.Environment]::NewLine){0}" -f $_.Exception.ToString());
            }
        }
        return $false;
    }

    # verify the current signature with the specified public key files (in AVM's format), the verification
    # will be passed, if any of the specified keys (better: any of the associated private keys) was used
    # to sign the image file
    [bool] verifySignature([string[]] $keyFileNames)
    {
        [SigningKey[]] $keys = [SigningKey[]] [System.Array]::CreateInstance([SigningKey], $keyFileNames.Count);
        [int] $index = 0;

        foreach ($name in $keyFileNames)
        {
            try
            {
                $keys[$index++] = [SigningKey]::FromASCFile($name);
            }
            catch
            {
                throw ("Error reading key file {0}.$([System.Environment]::NewLine){1}" -f $name, $_.Exception.ToString());
            }
        }
        return $this.verifySignature(([SigningKey[]]$keys));
    }

    # verify the current signature with the specified public key file (in AVM's format)
    [bool] verifySignature([string] $keyFileName)
    {
        return $this.verifySignature([string[]] @($keyFileName));
    }

    # add a new signature to the whole image data, replaces any existing signature or creates a new one
    [void] addSignature([SigningKey] $key)
    {
        if ($key.rsa.PublicOnly)
        {
            throw "The specified key does not contain the private parts of a RSA key - it may not be used to sign an image.";
        }

        foreach ($member in ([TarFile]$this).members)
        {
            $member.sealContent();
        }
        $this.garbageAtEnd = 0;

        [byte[]] $sigBytes = $key.rsa.SignData($this.signingStream(), "MD5", [System.Security.Cryptography.RSASignaturePadding]::Pkcs1);

        if ($this.signature -eq $null)
        {
            $this.signature = [TarMember]::new();
            $this.signature.fileName = "./var/signature";
            $this.signature.fileType = [TarMemberType]::RegularFile;
            $this.signature.fileMode = [System.Convert]::ToInt32("644", 8);
            # user and group name aren't necessary ... we will set them anyhow
            $this.signature.userName = "root";
            $this.signature.groupName = "root";
            $this.signature.size = 128;
            $this.members.Add($this.signature);
        }

        $this.signature.modTime = ([System.DateTimeOffset][System.DateTime]::Now).ToUnixTimeSeconds();
        $this.signature.fileTime = [System.DateTimeOffset]::FromUnixTimeSeconds($this.signature.modTime);
        $this.signature.signedHeader = [TarHeader]::new($this.signature).toBytes();
        $this.signature.hasSignedHeader = $true;
        $this.signature.data = [System.IO.MemoryStream]::new($sigBytes);
        $this.isSigned = $true;
    }

    # add a new signature to the whole image data, replaces any existing signature or creates a new one
    # and loads the needed key (which may be password protected) in PEM format from $keyFileName
    [void] addSignature([string] $keyFileName, [string] $password)
    {
        $this.addSignature([SigningKey]::FromRSAPrivateKeyFile($keyFileName, $password));
    }

    # add a new signature to the whole image data, replaces any existing signature or creates a new one,
    # using the specified RSA private key - the signed data is written to $outputFileName
    [void] addSignature([SigningKey] $key, [string] $outputFileName)
    {
        $this.addSignature($key);
        $this.contentStream().WriteTo([System.IO.File]::Create($outputFileName));
    }

    # add a new signature to the whole image data, replaces any existing signature or creates a new one
    # and loads the needed key (which may be password protected) in PEM format from $keyFileName; finally
    # the signed image file is store as $outputFileName
    [void] addSignature([string] $keyFileName, [string] $password, [string] $outputFileName)
    {
        $this.addSignature([SigningKey]::FromRSAPrivateKeyFile($keyFileName, $password), $outputFileName);
    }

    # remove an existing signature from this image
    [void] resetSignature()
    {
        # any change to the file structure invalidates the signature, so we'll remove it
        if ($this.isSigned)
        {
            $this.isSigned = $false;
            # any older garbage (which was needed to keep an old signature valid) may be ignore now, too
            $this.garbageAtEnd = 0;
            $this.removeMember($this.signature);
            $this.signature = $null;
        }
    }

    # remove the specified member from this image, any existing signature becomes invalid and will be removed, too
    [void] removeMember([TarMember] $member)
    {
        $this.resetSignature();
        ([TarFile]$this).removeMember($member);
    }

    # add the specified member to this image, after the last existing one
    # - if a signature exists, it's now invalid and will be removed, before the new member is added
    [void] addMember([TarMember] $member)
    {
        $this.resetSignature();
        ([TarFile]$this).AddMember($member);
    }

    # add the specified member to this image, at the specified position in the 'members' array
    # - if a signature exists, it's now invalid and will be removed, before the new member is added
    # - you have to consider any changes to the number of members or their positions in the dictionary,
    #   if the file is still signed - or you remove the signature first (with (hidden) 'removeSignature' method)
    [void] insertMember([TarMember] $member, [int] $position)
    {
        $this.removeSignature();
        ([TarFile]$this).insertMember($member, $position);
    }

    # search for a file with name 'signature' (preceded by any path) and a data size of 128 bytes - it's
    # assumed to be the signature file for this image
    hidden [bool] findSignature()
    {
        foreach ($member in $this.members)
        {
            if ($member.fileName.EndsWith("/signature") -and $member.size -eq 128)
            {
                $this.signature = $member;
                return $true;
            }
        }
        return $false;
    }

    # get the data stream used for signing an image from this object, either for verification purposes or
    # for adding an own signature
    hidden [System.IO.MemoryStream] signingStream()
    {
        [System.IO.MemoryStream] $sigStream = [System.IO.MemoryStream]::new();
        foreach ($member in ([TarFile]$this).members)
        {
            if ($member.Equals($this.signature))
            {
                $sigStream.Write([byte[]]::CreateInstance([byte], 2 * 512), 0, 2 * 512);
            }
            else
            {
                $member.getTarContent($true).WriteTo($sigStream);
            }
        }
        $sigStream.Write([byte[]]::CreateInstance([byte], (2 * 512) + $this.garbageAtEnd), 0, (2 * 512) + $this.garbageAtEnd);
        $sigStream.Seek(0, [System.IO.SeekOrigin]::Begin);
        return $sigStream;
    }

    # get the data stream for this image ... it will re-produce the same content as the loaded file (from the
    # last 'new' or 'Open' method call), as long as no changes were applied to the original members (content,
    # attributes, sort order, etc.) - its more or less the same stream as of 'signingStream' method, but here
    # a signature is contained, if any
    hidden [System.IO.MemoryStream] contentStream()
    {
        [System.IO.MemoryStream] $contStream = [System.IO.MemoryStream]::new();
        foreach ($member in ([TarFile]$this).members)
        {
            $member.getTarContent($false).WriteTo($contStream);
        }
        $contStream.Write([byte[]]::CreateInstance([byte], (2 * 512) + $this.garbageAtEnd), 0, (2 * 512) + $this.garbageAtEnd);
        $contStream.Seek(0, [System.IO.SeekOrigin]::Begin);
        return $contStream;
    }
}
