#######################################################################################################
#                                                                                                     #
# support communication with the FTP server in the bootloader (EVA) for AVM's FRITZ!Box devices       #
#                                                                                                     #
###################################################################################################VER#
#                                                                                                     #
# FTPtoEVA.ps1, version 0.3                                                                           #
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
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# Known problems/difficulties/inconsistencies:                                                        #
#                                                                                                     #
#                                                                                                     #
#######################################################################################################
Write-Host @'
This is "FTPtoEVA.ps1" ...

a PowerShell class to find starting FRITZ!Box devices via network and to access the FTP server of
the bootloader (EVA)

... from the YourFritz project at https://github.com/PeterPawn/YourFritz

(C) 2017-2018 P. Haemmerlein (peterpawn@yourfritz.de)

'@;
Write-Host -ForegroundColor Yellow "Look at the comment lines from the beginning of this file to get further info, how to make use of the provided class.$([System.Environment]::NewLine)";

Write-Host -ForegroundColor Green "The class is now ready to be used in this session.";
#######################################################################################################
#                                                                                                     #
# 'Add-Type' may only be called once in a session for the same type - therefore we check, if our own  #
# type is known already and if not, we'll add it to this session in the 'catch' block.                #
#                                                                                                     #
#######################################################################################################
try
{
    [YourFritz.EVA.Discovery] | Get-Member | Out-Null;
    Write-Host -ForegroundColor Red "The inline type definitions were NOT updated.";
}
catch
{
    Add-Type -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

/// This code uses older syntax from before C# 6, to be usable even from PowerShell 5.1 with .NET Framework.
/// With C# 6 and above, much new features may be used ... e.g. lambda expressions as method bodies or nullable
/// types for event handlers.

namespace YourFritz.Helpers
{
    class HexDump
    {
        public static string Dump(byte[] input)
        {
            System.Text.StringBuilder output = new System.Text.StringBuilder();
            int index = 0;
            int lastIndex = 0;

            {
                System.Text.StringBuilder line = new System.Text.StringBuilder();
                int b;
                string lastLine = System.String.Empty;

                for (index = 0; index < input.Length; index += 16)
                {
                    line.Clear();

                    for (b = 0; b < Math.Min(16, input.Length - index); b++)
                    {
                        line.Append(String.Format("{0:x2} ", input[index + b]));
                        if (b == 7) line.Append(" ");
                    }

                    if (b < 8) line.Append(" ");
                    while (b++ < 16) line.Append("   ");

                    line.Append(" |");
                    for (b = 0; b < Math.Min(16, input.Length - index); b++)
                    {
                        if ((input[index + b] < 32) || (input[index + b] > 127))
                        {
                            line.Append(".");
                        }
                        else
                        {
                            line.Append(System.Text.Encoding.ASCII.GetChars(input, index + b, 1));
                        }
                    }
                    line.Append("|");

                    if (line.ToString().CompareTo(lastLine) != 0)
                    {
                        if ((index > 0) && (lastIndex != (index - 16)) && (index < input.Length)) output.AppendLine("*");
                        lastLine = line.ToString();
                        output.AppendLine(String.Format("{0:x8}  {1:s}", index, lastLine));
                        lastIndex = index;
                    }
                }
            }

            if (lastIndex != (index - 16)) output.AppendLine("*");

            output.AppendLine(String.Format("{0:x8}", input.Length));

            return output.ToString();
        }
    }
}
namespace YourFritz.TFFS
{
    public class TFFSHelpers
    {
        // combine two or more byte array to one single bigger-one
        internal static byte[] CombineByteArrays(byte[][] inputArrays)
        {
            // count combined length of all arrays
            int count = 0;
            Array.ForEach<byte[]>(inputArrays, delegate (byte[] buffer) { count += buffer.Length; });

            byte[] output = new byte[count];
            count = 0;

            Array.ForEach<byte[]>(inputArrays, delegate (byte[] buffer) { System.Array.Copy(buffer, 0, output, count, buffer.Length); count += buffer.Length; });

            return output;
        }

        // TFFS uses big endian order for numbers, get the bytes for a 32-bit value
        internal static byte[] GetBytesBE(int input)
        {
            byte[] output = System.BitConverter.GetBytes(input);

            if (System.BitConverter.IsLittleEndian)
            {
                System.Array.Reverse(output, 0, sizeof(int));
            }

            return output;
        }

        // TFFS uses big endian order for numbers, get the bytes for a 16-bit value
        internal static byte[] GetBytesBE(System.UInt16 input)
        {
            byte[] output = System.BitConverter.GetBytes(input);

            if (System.BitConverter.IsLittleEndian)
            {
                System.Array.Reverse(output, 0, sizeof(System.UInt16));
            }

            return output;
        }
    }

    public class TFFSException : Exception
    {
        public TFFSException()
        {
        }

        public TFFSException(string message)
            : base(message)
        {
        }

        public TFFSException(string message, Exception inner) : base(message, inner)
        {
        }
    }

    public enum TFFSEnvironmentID
    {
        // management IDs
        Free = -1,
        Removed = 0,
        Segment = 1,
        // file IDs, not affected by factory settings
        ProviderAdditive = 29,
        ProviderDefault_DHCPLeases = 30,
        ProviderDefault_AR7Config = 31,
        ChronyDrift = 32,
        ChronyRTC = 33,
        ProviderDefault_VoIPConfig = 34,
        ProviderDefault_WLANConfig = 35,
        ProviderDefault_Statistics = 36,
        ProviderDefault_NetUpdate = 37,
        ProviderDefault_VPNConfig = 38,
        ProviderDefault_TR069Config = 39,
        ProviderDefault_UserProfiles = 40,
        ProviderDefault_UserStatistics = 41,
        ProviderDefault_VoIPCallStatistics = 42,
        ProviderDefault_RepeaterConfig = 43,
        ProviderDefault_Repeater_NG_Config = 44,
        ProviderDefault_PIN = 45,
        ProviderDefault_HCIDConfig = 46,
        ProviderDefault_LinkKey = 47,
        ProviderDefault_MSNs = 48,
        ProviderDefault_PhoneConfig = 49,
        ProviderDefault_LCRConfig = 50,
        ProviderDefault_MOH1Prompt = 51,
        ProviderDefault_XmlCallLog = 52,
        ProviderDefault_PhoneMisc = 53,
        ProviderDefault_MOH2Prompt = 54,
        ProviderDefault_NoServicePrompt = 55,
        ProviderDefault_NoNumberPrompt = 56,
        ProviderDefault_User1Prompt = 57,
        ProviderDefault_User2Prompt = 58,
        ProviderDefault_User3Prompt = 59,
        FreetzConfig = 60,
        ProviderDefault_IncomingCallHookScript = 61,
        ProviderDefault_XmlPhonebook = 62,
        ProviderDefault_PhoneControl = 63,
        ProviderDefault_PowerMode = 64,
        ProviderDefault_AuraUSB = 65,
        ProviderDefault_DocsisNvRam = 66,
        ProviderDefault_UnusedUpdateURL = 67,
        ProviderDefault_DectMisc = 68,
        ProviderDefault_DectEEPROM = 69,
        ProviderDefault_DectHandsetUser = 70,
        ProviderDefault_RSAPrivateKey = 71,
        ProviderDefault_RSACertificate = 72,
        ProviderDefault_RasCertificate = 73,
        ProviderDefault_USBConfig = 74,
        ProviderDefault_xDSLMode = 75,
        ProviderDefault_UMTSConfig = 76,
        ProviderDefault_MailDaemonConfig = 77,
        ProviderDefault_TimeProfile = 78,
        ProviderDefault_DectConfig = 79,
        FirmwareAttributes = 87,
        CrashLog2 = 93,
        PanicLog2 = 94,
        CrashLog = 95,
        PanicLog = 96,
        ReservedUser = 97,
        User = 98,
        PhoneDefaults = 99,
        // file IDs, thrown away by factory settings
        FactorySettingsBegin = 100,
        DHCPLeases = 112,
        AR7Config = 113,
        VoIPConfig = 114,
        WLANConfig = 115,
        Statistics = 116,
        NetUpdate = 117,
        VPNConfig = 118,
        TR069Config = 119,
        UserProfiles = 120,
        UserStatistics = 121,
        VoIPCallStatistics = 122,
        RepeaterConfig = 123,
        Repeater_NG_Config = 124,
        PIN = 125,
        HCIDConfig = 126,
        LinkKey = 127,
        MSNs = 128,
        PhoneConfig = 129,
        LCRConfig = 130,
        MOH1Prompt = 131,
        XmlCallLog = 132,
        PhoneMisc = 133,
        MOH2Prompt = 134,
        NoServicePrompt = 135,
        NoNumberPrompt = 136,
        User1Prompt = 137,
        User2Prompt = 138,
        User3Prompt = 139,
        IncomingCallHookScript = 141,
        Xmlhonebook = 142,
        PhoneControl = 143,
        PowerMode = 144,
        TAMConfig = 145,
        AuraUSB = 160,
        DECTConfig = 161,
        KnownLANDevices = 162,
        FirmwareUpdateTrace = 163,
        DocsisNvRam = 168,
        UnusedUpdateURL = 169,
        DectMisc = 176,
        DectEEPROM = 177,
        DectHandsetUser = 178,
        PluginGlobal = 192,
        Plugin1 = 193,
        Plugin2 = 194,
        Plugin3 = 195,
        Plugin4 = 196,
        Plugin5 = 197,
        Plugin6 = 198,
        Plugin7 = 199,
        Plugin8 = 200,
        RSAPrivateKey = 201,
        RSACertifikate = 202,
        LetsEncryptPrivateKey = 203,
        LetsEncryptCertificate = 204,
        NexusConfig = 205,
        RasCertificate = 208,
        USBConfig = 209,
        xDSLMode = 210,
        UMTSConfig = 211,
        MailDaemonConfig = 212,
        TimeProfile = 213,
        SavedEvents = 214,
        FeaturesOverlay = 215,
        USBModemSettings = 216,
        PowerlineConfig = 217,
        ModuleMemoryFile = 218,
        DVBConfig = 219,
        SmartMeterConfig = 224,
        SmartHomeConfig = 225,
        SmartHomeUserConfig = 226,
        SmartHomeStatistics = 227,
        SmartHomeDectConfig = 228,
        SmartHomeNetworkConfig = 229,
        SmartHomeGlobalConfig = 230,
        SmartHomePushMailConfig = 231,
        FactorySettingsEnd = 255,
        // environment variables
        HWRevision = 256,
        ProductID = 257,
        SerialNumber = 258,
        DMC = 259,
        HWSubRevision = 260,
        AutoLoad = 385,
        BootloaderVersion = 386,
        BootSerialPort = 387,
        BluetoothMAC = 388,
        CPUFrequency = 389,
        FirstFreeAddress = 390,
        FlashSize = 391,
        MAC_A = 392,
        MAC_B = 393,
        MAC_WLAN = 394,
        MAC_DSL = 395,
        MemorySize = 396,
        ModeTTY0 = 397,
        ModeTTY1 = 398,
        IPAddress = 399,
        EVAPrompt = 400,
        MAC_reserved = 401,
        FullRateFrequency = 402,
        SysFrequency = 403,
        MAC_USB_Board = 404,
        MAC_USB_Network = 405,
        MAC_WLAN2 = 406,
        LinuxFSStart = 408,
        NFS = 411,
        NFSRoot = 412,
        KernelArgs1 = 415,
        KernelArgs = 416,
        Crash = 417,
        USBDeviceID = 418,
        USBRevisionID = 419,
        USBDeviceName = 420,
        USBManufacturerName = 421,
        FirmwareVersion = 422,
        Language = 423,
        Country = 424,
        Annex = 425,
        ProdTest = 426,
        WLANKey = 427,
        BluetoothKey = 428,
        FirmwareInfo = 430,
        AutoMDIX = 431,
        MTD0 = 432,
        MTD1 = 433,
        MTD2 = 434,
        MTD3 = 435,
        MTD4 = 436,
        MTD5 = 437,
        MTD6 = 438,
        MTD7 = 439,
        WLANCalibration = 440,
        JFFS2Size = 441,
        MTD8 = 442,
        MTD9 = 443,
        MTD10 = 444,
        MTD11 = 445,
        MTD12 = 446,
        MTD13 = 447,
        TR069Serial = 448,
        TR069Passphrase = 449,
        GUIPassword = 450,
        Provider = 451,
        ModuleMemory = 452,
        PowerlineID = 453,
        MTD14 = 454,
        MTD15 = 455,
        WLAN_SSID = 456,
        UrladerVersion = 509,
        NameTableVersion = 510,
        NameTableID = 511,
        Blob0 = 512,
        Blob1 = 513,
        Blob2 = 514,
        Blob3 = 515,
        Blob4 = 516,
        Blob5 = 517,
        Blob6 = 518,
        Blob7 = 519,
        Blob8 = 520,
        Blob9 = 521,
        // counter values
        RebootMajor = 1024,
        RebootMinor = 1025,
        RunningHours = 1026,
        RunningDays = 1027,
        RunningMonth = 1028,
        RunningYears = 1029,
        ReservedCounter = 1030,
        VersionCounter = 1031,
        // droppable data - maybe it is never written by the driver
        DroppableData = 16384,
        Assertion = 16385,
        ATMJournal = 16386,
    }

    public class TFFSEnvironmentEntry
    {
        private string p_Name;
        private TFFSEnvironmentID p_ID;

        public TFFSEnvironmentEntry(TFFSEnvironmentID ID, string Name)
        {
            this.p_ID = ID;
            this.p_Name = Name;
        }

        public TFFSEnvironmentID ID
        {
            get
            {
                return this.p_ID;
            }
        }

        public string Name
        {
            get
            {
                return this.p_Name;
            }
        }

        public byte[] ImageBytes
        {
            get
            {
                byte[] name = System.Text.Encoding.ASCII.GetBytes(this.p_Name);
                byte[] aligned = new byte[((name.Length + 1) + 3) & ~3];
                System.Array.Copy(name, aligned, name.Length);
                return TFFSHelpers.CombineByteArrays(new byte[][] { TFFSHelpers.GetBytesBE((int)this.p_ID), aligned });
            }
        }
    }

    public class TFFSEnvironmentEntries : System.Collections.Generic.Dictionary<TFFSEnvironmentID, TFFSEnvironmentEntry>
    {
    }

    public class TFFSEntryFactory
    {
        static private TFFSEnvironmentEntries sp_Entries;

        public static TFFSEnvironmentEntries GetEntries()
        {
            if (TFFSEntryFactory.sp_Entries != null)
            {
                return TFFSEntryFactory.sp_Entries;
            }

            TFFSEnvironmentEntries entries = new TFFSEnvironmentEntries();
            TFFSEntryFactory.sp_Entries = entries;

            entries.Add(TFFSEnvironmentID.AutoMDIX, new TFFSEnvironmentEntry(TFFSEnvironmentID.AutoMDIX, "AutoMDIX"));
            entries.Add(TFFSEnvironmentID.DMC, new TFFSEnvironmentEntry(TFFSEnvironmentID.DMC, "DMC"));
            entries.Add(TFFSEnvironmentID.HWRevision, new TFFSEnvironmentEntry(TFFSEnvironmentID.HWRevision, "HWRevision"));
            entries.Add(TFFSEnvironmentID.HWSubRevision, new TFFSEnvironmentEntry(TFFSEnvironmentID.HWSubRevision, "HWSubRevision"));
            entries.Add(TFFSEnvironmentID.ProductID, new TFFSEnvironmentEntry(TFFSEnvironmentID.ProductID, "ProductID"));
            entries.Add(TFFSEnvironmentID.SerialNumber, new TFFSEnvironmentEntry(TFFSEnvironmentID.SerialNumber, "SerialNumber"));
            entries.Add(TFFSEnvironmentID.Annex, new TFFSEnvironmentEntry(TFFSEnvironmentID.Annex, "annex"));
            entries.Add(TFFSEnvironmentID.AutoLoad, new TFFSEnvironmentEntry(TFFSEnvironmentID.AutoLoad, "autoload"));
            entries.Add(TFFSEnvironmentID.Blob0, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob0, "bb0"));
            entries.Add(TFFSEnvironmentID.Blob1, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob1, "bb1"));
            entries.Add(TFFSEnvironmentID.Blob2, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob2, "bb2"));
            entries.Add(TFFSEnvironmentID.Blob3, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob3, "bb3"));
            entries.Add(TFFSEnvironmentID.Blob4, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob4, "bb4"));
            entries.Add(TFFSEnvironmentID.Blob5, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob5, "bb5"));
            entries.Add(TFFSEnvironmentID.Blob6, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob6, "bb6"));
            entries.Add(TFFSEnvironmentID.Blob7, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob7, "bb7"));
            entries.Add(TFFSEnvironmentID.Blob8, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob8, "bb8"));
            entries.Add(TFFSEnvironmentID.Blob9, new TFFSEnvironmentEntry(TFFSEnvironmentID.Blob9, "bb9"));
            entries.Add(TFFSEnvironmentID.BootloaderVersion, new TFFSEnvironmentEntry(TFFSEnvironmentID.BootloaderVersion, "bootloaderVersion"));
            entries.Add(TFFSEnvironmentID.BootSerialPort, new TFFSEnvironmentEntry(TFFSEnvironmentID.BootSerialPort, "bootserport"));
            entries.Add(TFFSEnvironmentID.BluetoothKey, new TFFSEnvironmentEntry(TFFSEnvironmentID.BluetoothKey, "bluetooth_key"));
            entries.Add(TFFSEnvironmentID.BluetoothMAC, new TFFSEnvironmentEntry(TFFSEnvironmentID.BluetoothMAC, "bluetooth"));
            entries.Add(TFFSEnvironmentID.Country, new TFFSEnvironmentEntry(TFFSEnvironmentID.Country, "country"));
            entries.Add(TFFSEnvironmentID.CPUFrequency, new TFFSEnvironmentEntry(TFFSEnvironmentID.CPUFrequency, "cpufrequency"));
            entries.Add(TFFSEnvironmentID.Crash, new TFFSEnvironmentEntry(TFFSEnvironmentID.Crash, "crash"));
            entries.Add(TFFSEnvironmentID.FirstFreeAddress, new TFFSEnvironmentEntry(TFFSEnvironmentID.FirstFreeAddress, "firstfreeaddress"));
            entries.Add(TFFSEnvironmentID.FirmwareInfo, new TFFSEnvironmentEntry(TFFSEnvironmentID.FirmwareInfo, "firmware_info"));
            entries.Add(TFFSEnvironmentID.FirmwareVersion, new TFFSEnvironmentEntry(TFFSEnvironmentID.FirmwareVersion, "firmware_version"));
            entries.Add(TFFSEnvironmentID.FlashSize, new TFFSEnvironmentEntry(TFFSEnvironmentID.FlashSize, "flashsize"));
            entries.Add(TFFSEnvironmentID.JFFS2Size, new TFFSEnvironmentEntry(TFFSEnvironmentID.JFFS2Size, "jffs2_size"));
            entries.Add(TFFSEnvironmentID.KernelArgs, new TFFSEnvironmentEntry(TFFSEnvironmentID.KernelArgs, "kernel_args"));
            entries.Add(TFFSEnvironmentID.KernelArgs1, new TFFSEnvironmentEntry(TFFSEnvironmentID.KernelArgs1, "kernel_args1"));
            entries.Add(TFFSEnvironmentID.Language, new TFFSEnvironmentEntry(TFFSEnvironmentID.Language, "language"));
            entries.Add(TFFSEnvironmentID.LinuxFSStart, new TFFSEnvironmentEntry(TFFSEnvironmentID.LinuxFSStart, "linux_fs_start"));
            entries.Add(TFFSEnvironmentID.MAC_A, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_A, "maca"));
            entries.Add(TFFSEnvironmentID.MAC_B, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_B, "macb"));
            entries.Add(TFFSEnvironmentID.MAC_WLAN, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_WLAN, "macwlan"));
            entries.Add(TFFSEnvironmentID.MAC_WLAN2, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_WLAN2, "macwlan2"));
            entries.Add(TFFSEnvironmentID.MAC_DSL, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_DSL, "macdsl"));
            entries.Add(TFFSEnvironmentID.MemorySize, new TFFSEnvironmentEntry(TFFSEnvironmentID.MemorySize, "memsize"));
            entries.Add(TFFSEnvironmentID.ModeTTY0, new TFFSEnvironmentEntry(TFFSEnvironmentID.ModeTTY0, "modetty0"));
            entries.Add(TFFSEnvironmentID.ModeTTY1, new TFFSEnvironmentEntry(TFFSEnvironmentID.ModeTTY1, "modetty1"));
            entries.Add(TFFSEnvironmentID.ModuleMemory, new TFFSEnvironmentEntry(TFFSEnvironmentID.ModuleMemory, "modulemem"));
            entries.Add(TFFSEnvironmentID.MTD0, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD0, "mtd0"));
            entries.Add(TFFSEnvironmentID.MTD1, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD1, "mtd1"));
            entries.Add(TFFSEnvironmentID.MTD2, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD2, "mtd2"));
            entries.Add(TFFSEnvironmentID.MTD3, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD3, "mtd3"));
            entries.Add(TFFSEnvironmentID.MTD4, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD4, "mtd4"));
            entries.Add(TFFSEnvironmentID.MTD5, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD5, "mtd5"));
            entries.Add(TFFSEnvironmentID.MTD6, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD6, "mtd6"));
            entries.Add(TFFSEnvironmentID.MTD7, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD7, "mtd7"));
            entries.Add(TFFSEnvironmentID.MTD8, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD8, "mtd8"));
            entries.Add(TFFSEnvironmentID.MTD9, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD9, "mtd9"));
            entries.Add(TFFSEnvironmentID.MTD10, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD10, "mtd10"));
            entries.Add(TFFSEnvironmentID.MTD11, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD11, "mtd11"));
            entries.Add(TFFSEnvironmentID.MTD12, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD12, "mtd12"));
            entries.Add(TFFSEnvironmentID.MTD13, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD13, "mtd13"));
            entries.Add(TFFSEnvironmentID.MTD14, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD14, "mtd14"));
            entries.Add(TFFSEnvironmentID.MTD15, new TFFSEnvironmentEntry(TFFSEnvironmentID.MTD15, "mtd15"));
            entries.Add(TFFSEnvironmentID.IPAddress, new TFFSEnvironmentEntry(TFFSEnvironmentID.IPAddress, "my_ipaddress"));
            entries.Add(TFFSEnvironmentID.NFS, new TFFSEnvironmentEntry(TFFSEnvironmentID.NFS, "nfs"));
            entries.Add(TFFSEnvironmentID.NFSRoot, new TFFSEnvironmentEntry(TFFSEnvironmentID.NFSRoot, "nfsroot"));
            entries.Add(TFFSEnvironmentID.PowerlineID, new TFFSEnvironmentEntry(TFFSEnvironmentID.PowerlineID, "plc_dak_nmk"));
            entries.Add(TFFSEnvironmentID.EVAPrompt, new TFFSEnvironmentEntry(TFFSEnvironmentID.EVAPrompt, "prompt"));
            entries.Add(TFFSEnvironmentID.Provider, new TFFSEnvironmentEntry(TFFSEnvironmentID.Provider, "provider"));
            entries.Add(TFFSEnvironmentID.ProdTest, new TFFSEnvironmentEntry(TFFSEnvironmentID.ProdTest, "ptest"));
            entries.Add(TFFSEnvironmentID.MAC_reserved, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_reserved, "reserved"));
            entries.Add(TFFSEnvironmentID.FullRateFrequency, new TFFSEnvironmentEntry(TFFSEnvironmentID.FullRateFrequency, "req_fullrate_freq"));
            entries.Add(TFFSEnvironmentID.SysFrequency, new TFFSEnvironmentEntry(TFFSEnvironmentID.SysFrequency, "sysfrequency"));
            entries.Add(TFFSEnvironmentID.TR069Passphrase, new TFFSEnvironmentEntry(TFFSEnvironmentID.TR069Passphrase, "tr069_passphrase"));
            entries.Add(TFFSEnvironmentID.TR069Serial, new TFFSEnvironmentEntry(TFFSEnvironmentID.TR069Serial, "tr069_serial"));
            entries.Add(TFFSEnvironmentID.UrladerVersion, new TFFSEnvironmentEntry(TFFSEnvironmentID.UrladerVersion, "urlader-version"));
            entries.Add(TFFSEnvironmentID.MAC_USB_Board, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_USB_Board, "usb_board_mac"));
            entries.Add(TFFSEnvironmentID.USBDeviceID, new TFFSEnvironmentEntry(TFFSEnvironmentID.USBDeviceID, "usb_device_id"));
            entries.Add(TFFSEnvironmentID.USBDeviceName, new TFFSEnvironmentEntry(TFFSEnvironmentID.USBDeviceName, "usb_device_name"));
            entries.Add(TFFSEnvironmentID.USBManufacturerName, new TFFSEnvironmentEntry(TFFSEnvironmentID.USBManufacturerName, "usb_manufacturer_name"));
            entries.Add(TFFSEnvironmentID.USBRevisionID, new TFFSEnvironmentEntry(TFFSEnvironmentID.USBRevisionID, "usb_revision_id"));
            entries.Add(TFFSEnvironmentID.MAC_USB_Network, new TFFSEnvironmentEntry(TFFSEnvironmentID.MAC_USB_Network, "usb_rndis_mac"));
            entries.Add(TFFSEnvironmentID.GUIPassword, new TFFSEnvironmentEntry(TFFSEnvironmentID.GUIPassword, "webgui_pass"));
            entries.Add(TFFSEnvironmentID.WLANCalibration, new TFFSEnvironmentEntry(TFFSEnvironmentID.WLANCalibration, "wlan_cal"));
            entries.Add(TFFSEnvironmentID.WLANKey, new TFFSEnvironmentEntry(TFFSEnvironmentID.WLANKey, "wlan_key"));
            entries.Add(TFFSEnvironmentID.WLAN_SSID, new TFFSEnvironmentEntry(TFFSEnvironmentID.WLAN_SSID, "wlan_ssid"));
            entries.Add(TFFSEnvironmentID.Removed, new TFFSEnvironmentEntry(TFFSEnvironmentID.Removed, "zuende"));

            return TFFSEntryFactory.sp_Entries;
        }
    }

    public class TFFSNameTableEntries : System.Collections.Generic.List<TFFSEnvironmentID>
    {
    }

    public class TFFSNameTable
    {
        private TFFSEnvironmentEntry p_Version;
        private TFFSEnvironmentEntries p_Entries;
        private TFFSNameTableEntries p_Order;

        public TFFSNameTable(string Version, TFFSNameTableEntries Entries)
        {
            this.p_Entries = new TFFSEnvironmentEntries();
            this.p_Version = new TFFSEnvironmentEntry(TFFSEnvironmentID.NameTableVersion, Version);
            foreach (TFFSEnvironmentID entry in Entries)
            {
                this.p_Entries.Add(entry, (TFFSEntryFactory.GetEntries()[entry]));
            }
            this.p_Order = Entries;
        }

        public string Version
        {
            get
            {
                return this.p_Version.Name;
            }
        }

        public TFFSEnvironmentEntries Entries
        {
            get
            {
                return this.p_Entries;
            }
        }

        // get a buffer with table in image format - the kernel uses fix-sized entries (with 64 bytes length for the name)
        public byte[] ImageBytes
        {
            get
            {
                // we start with our version entry
                byte[] output = this.p_Version.ImageBytes;

                // and append each other entry in the correct order
                this.p_Order.ForEach(id => output = TFFSHelpers.CombineByteArrays(new byte[][] { output, this.p_Entries[id].ImageBytes }));

                // prepend it with the correct environment ID and length of the table
                output = TFFSHelpers.CombineByteArrays(new byte[][] { TFFSHelpers.GetBytesBE((System.UInt16)TFFSEnvironmentID.NameTableID), TFFSHelpers.GetBytesBE((System.UInt16)output.Length), output });

                return output;
            }
        }

        // generate name tables in various (known) versions
        public static TFFSNameTable GetNameTable(string Version)
        {
            TFFSNameTableEntries entries = new TFFSNameTableEntries();

            // Supported versions are between @G and @L, incl. - the differences between @G and @H are unknown - possibly the ID was
            // only incremented to reflect the new TFFS2 version support.
            // @I has introduced <linux_fs_start> and <modulemem> values.
            // @J changes are unknown, too - I could not find a source from AVM for this version, so I have implemented it as @I without
            //    <nfs> and <nfsroot> values and with correctly sorted names (alphabetically)
            // @K later has added 6490 support - more MTD definitions, crash and panic log for the 2nd system, DVB configuration, TFFS3
            //    support - which of these changes were contained in @J already, is currently unknown.
            // @L (the current version) has added the individual WLAN SSID with two additional characters. Various "Mesh"-related
            //    changes have taken place in "tffs.h", but the name table was not changed anymore.
            if (Version.CompareTo("@G") != 0 &&
                Version.CompareTo("@H") != 0 &&
                Version.CompareTo("@I") != 0 &&
                Version.CompareTo("@J") != 0 &&
                Version.CompareTo("@K") != 0 &&
                Version.CompareTo("@L") != 0)
            {
                throw new TFFSException("Only name table versions from @G (used in 2010) to @L (current) are supported yet.");
            }

            entries.Add(TFFSEnvironmentID.AutoMDIX);
            entries.Add(TFFSEnvironmentID.DMC);
            entries.Add(TFFSEnvironmentID.HWRevision);
            entries.Add(TFFSEnvironmentID.HWSubRevision);
            entries.Add(TFFSEnvironmentID.ProductID);
            entries.Add(TFFSEnvironmentID.SerialNumber);
            entries.Add(TFFSEnvironmentID.Annex);
            entries.Add(TFFSEnvironmentID.AutoLoad);
            entries.Add(TFFSEnvironmentID.Blob0);
            entries.Add(TFFSEnvironmentID.Blob1);
            entries.Add(TFFSEnvironmentID.Blob2);
            entries.Add(TFFSEnvironmentID.Blob3);
            entries.Add(TFFSEnvironmentID.Blob4);
            entries.Add(TFFSEnvironmentID.Blob5);
            entries.Add(TFFSEnvironmentID.Blob6);
            entries.Add(TFFSEnvironmentID.Blob7);
            entries.Add(TFFSEnvironmentID.Blob8);
            entries.Add(TFFSEnvironmentID.Blob9);
            entries.Add(TFFSEnvironmentID.BootloaderVersion);
            entries.Add(TFFSEnvironmentID.BootSerialPort);
            entries.Add(TFFSEnvironmentID.BluetoothKey);
            entries.Add(TFFSEnvironmentID.BluetoothMAC);
            entries.Add(TFFSEnvironmentID.Country);
            entries.Add(TFFSEnvironmentID.CPUFrequency);
            entries.Add(TFFSEnvironmentID.Crash);
            entries.Add(TFFSEnvironmentID.FirstFreeAddress);

            if (Version.CompareTo("@I") == 1)
            {
                // correct sort order after @I
                entries.Add(TFFSEnvironmentID.FirmwareInfo);
                entries.Add(TFFSEnvironmentID.FirmwareVersion);
            }
            else
            {
                // up to and incl. @I, these entries are out of (sort) order
                entries.Add(TFFSEnvironmentID.FirmwareVersion);
                entries.Add(TFFSEnvironmentID.FirmwareInfo);
            }

            entries.Add(TFFSEnvironmentID.FlashSize);
            entries.Add(TFFSEnvironmentID.JFFS2Size);
            entries.Add(TFFSEnvironmentID.KernelArgs);
            entries.Add(TFFSEnvironmentID.KernelArgs1);
            entries.Add(TFFSEnvironmentID.Language);

            if (Version.CompareTo("@H") == 1)
            {
                // this entry was hidden before @H (it was only a comment)
                entries.Add(TFFSEnvironmentID.LinuxFSStart);
            }

            entries.Add(TFFSEnvironmentID.MAC_A);
            entries.Add(TFFSEnvironmentID.MAC_B);
            entries.Add(TFFSEnvironmentID.MAC_WLAN);
            entries.Add(TFFSEnvironmentID.MAC_WLAN2);
            entries.Add(TFFSEnvironmentID.MAC_DSL);
            entries.Add(TFFSEnvironmentID.MemorySize);
            entries.Add(TFFSEnvironmentID.ModeTTY0);
            entries.Add(TFFSEnvironmentID.ModeTTY1);

            if (Version.CompareTo("@H") == 1)
            {
                // added in @I
                entries.Add(TFFSEnvironmentID.ModuleMemory);
            }

            entries.Add(TFFSEnvironmentID.MTD0);
            entries.Add(TFFSEnvironmentID.MTD1);
            entries.Add(TFFSEnvironmentID.MTD2);
            entries.Add(TFFSEnvironmentID.MTD3);
            entries.Add(TFFSEnvironmentID.MTD4);
            entries.Add(TFFSEnvironmentID.MTD5);
            entries.Add(TFFSEnvironmentID.MTD6);
            entries.Add(TFFSEnvironmentID.MTD7);

            if (Version.CompareTo("@I") == 1)
            {
                // additional MTD entries after @I
                entries.Add(TFFSEnvironmentID.MTD8);
                entries.Add(TFFSEnvironmentID.MTD9);
                entries.Add(TFFSEnvironmentID.MTD10);
                entries.Add(TFFSEnvironmentID.MTD11);
                entries.Add(TFFSEnvironmentID.MTD12);
                entries.Add(TFFSEnvironmentID.MTD13);
                entries.Add(TFFSEnvironmentID.MTD14);
                entries.Add(TFFSEnvironmentID.MTD15);
            }

            entries.Add(TFFSEnvironmentID.IPAddress);

            if (Version.CompareTo("@I") != 1)
            {
                // up to @I these two entries exist
                entries.Add(TFFSEnvironmentID.NFS);
                entries.Add(TFFSEnvironmentID.NFSRoot);
            }

            if (Version.CompareTo("@K") != -1)
            {
                // starting with @K (maybe it exists in @J already)
                entries.Add(TFFSEnvironmentID.PowerlineID);
            }

            entries.Add(TFFSEnvironmentID.EVAPrompt);
            entries.Add(TFFSEnvironmentID.Provider);
            entries.Add(TFFSEnvironmentID.ProdTest);
            entries.Add(TFFSEnvironmentID.MAC_reserved);
            entries.Add(TFFSEnvironmentID.FullRateFrequency);
            entries.Add(TFFSEnvironmentID.SysFrequency);
            entries.Add(TFFSEnvironmentID.TR069Passphrase);
            entries.Add(TFFSEnvironmentID.TR069Serial);
            entries.Add(TFFSEnvironmentID.UrladerVersion);
            entries.Add(TFFSEnvironmentID.MAC_USB_Board);

            if (Version.CompareTo("@I") == 1)
            {
                // sort order was changed here
                entries.Add(TFFSEnvironmentID.USBDeviceID);
                entries.Add(TFFSEnvironmentID.USBDeviceName);
                entries.Add(TFFSEnvironmentID.USBManufacturerName);
                entries.Add(TFFSEnvironmentID.USBRevisionID);
                entries.Add(TFFSEnvironmentID.MAC_USB_Network);
            }
            else
            {
                entries.Add(TFFSEnvironmentID.MAC_USB_Network);
                entries.Add(TFFSEnvironmentID.USBDeviceID);
                entries.Add(TFFSEnvironmentID.USBRevisionID);
                entries.Add(TFFSEnvironmentID.USBDeviceName);
                entries.Add(TFFSEnvironmentID.USBManufacturerName);
            }

            entries.Add(TFFSEnvironmentID.GUIPassword);

            if (Version.CompareTo("@I") == 1)
            {
                entries.Add(TFFSEnvironmentID.WLANCalibration);
                entries.Add(TFFSEnvironmentID.WLANKey);
            }
            else
            {
                entries.Add(TFFSEnvironmentID.WLANKey);
                entries.Add(TFFSEnvironmentID.WLANCalibration);
            }

            if (Version.CompareTo("@K") == 1)
            {
                // individual WLAN SSIDs starting with @K
                entries.Add(TFFSEnvironmentID.WLAN_SSID);
            }

            return new TFFSNameTable(Version, entries);
        }
    }

    public class DumpNameTable
    {
        static void Main(string[] args)
        {
            string version = "@L";

            if (args.Length > 0 && args[0].Length > 0) version = args[0];

            Console.Write(YourFritz.Helpers.HexDump.Dump(TFFSNameTable.GetNameTable(version).ImageBytes));
        }
    }
}

namespace YourFritz.EVA
{
    public enum EVAMediaType
    {
        // access flash partition
        Flash,
        // access device RAM
        RAM,
    }

    public class EVAMedia
    {
        private EVAMediaType p_Type;
        private string p_Name;

        public EVAMedia(EVAMediaType MediaType, string Name)
        {
            this.p_Type = MediaType;
            this.p_Name = Name;
        }

        public EVAMediaType MediaType
        {
            get
            {
                return this.p_Type;
            }
        }

        public string Name
        {
            get
            {
                return this.p_Name;
            }
        }
    }

    public class EVAMediaDictionary : System.Collections.Generic.Dictionary<EVAMediaType, EVAMedia>
    {
    }

    public class EVAMediaFactory
    {
        static private EVAMediaDictionary sp_Media;

        public static EVAMediaDictionary GetMedia()
        {
            if (EVAMediaFactory.sp_Media != null)
            {
                return EVAMediaFactory.sp_Media;
            }

            EVAMediaDictionary media = new EVAMediaDictionary();
            EVAMediaFactory.sp_Media = media;

            media.Add(EVAMediaType.Flash, new EVAMedia(EVAMediaType.Flash, "FLSH"));
            media.Add(EVAMediaType.RAM, new EVAMedia(EVAMediaType.Flash, "SDRAM"));

            return EVAMediaFactory.sp_Media;
        }
    }

    public enum EVADataMode
    {
        // transfer data as ASCII, convert newline characters to host value
        Ascii,
        // transfer data as binary image
        Binary,
    }

    public class EVADataModeValue
    {
        private EVADataMode p_Mode;
        private string p_Name;

        public EVADataModeValue(EVADataMode DataMode, string Name)
        {
            this.p_Mode = DataMode;
            this.p_Name = Name;
        }

        public EVADataMode DataMode
        {
            get
            {
                return this.p_Mode;
            }
        }

        public string Name
        {
            get
            {
                return this.p_Name;
            }
        }
    }

    public class EVADataModeValues : System.Collections.Generic.Dictionary<EVADataMode, EVADataModeValue>
    {
    }

    public class EVADataModeFactory
    {
        static private EVADataModeValues sp_Modes;

        public static EVADataModeValues GetModes()
        {
            if (EVADataModeFactory.sp_Modes != null)
            {
                return EVADataModeFactory.sp_Modes;
            }

            EVADataModeValues modes = new EVADataModeValues();
            EVADataModeFactory.sp_Modes = modes;

            modes.Add(EVADataMode.Ascii, new EVADataModeValue(EVADataMode.Ascii, "A"));
            modes.Add(EVADataMode.Binary, new EVADataModeValue(EVADataMode.Binary, "I"));

            return EVADataModeFactory.sp_Modes;
        }
    }

    public enum EVAFileType
    {
        // TFFS environment
        Environment,
        // counter values from TFFS, if any - sometimes invalid data is returned (e.g. Puma6 devices)
        Counter,
        // device configuration area, created at finalization during manufacturing
        Configuration,
        // codec file - may be a relict from DaVinci devices
        Codec,
    }

    public class EVAFile
    {
        private EVAFileType p_Type;
        private string p_Name;

        public EVAFile(EVAFileType FileType, string Name)
        {
            this.p_Type = FileType;
            this.p_Name = Name;
        }

        public EVAFileType FileType
        {
            get
            {
                return this.p_Type;
            }
        }

        public string Name
        {
            get
            {
                return this.p_Name;
            }
        }
    }

    public class EVAFiles : System.Collections.Generic.List<EVAFile>
    {
    }

    public class EVAFileFactory
    {
        static private EVAFiles sp_Files;

        public static EVAFiles GetFiles()
        {
            if (EVAFileFactory.sp_Files != null)
            {
                return EVAFileFactory.sp_Files;
            }

            EVAFiles files = new EVAFiles();
            EVAFileFactory.sp_Files = files;

            files.Add(new EVAFile(EVAFileType.Environment, "env"));
            files.Add(new EVAFile(EVAFileType.Environment, "env1"));
            files.Add(new EVAFile(EVAFileType.Environment, "env2"));
            files.Add(new EVAFile(EVAFileType.Environment, "env3"));
            files.Add(new EVAFile(EVAFileType.Environment, "env4"));
            files.Add(new EVAFile(EVAFileType.Counter, "count"));
            files.Add(new EVAFile(EVAFileType.Configuration, "CONFIG"));
            files.Add(new EVAFile(EVAFileType.Configuration, "config"));
            files.Add(new EVAFile(EVAFileType.Codec, "codec0"));
            files.Add(new EVAFile(EVAFileType.Codec, "codec1"));

            return EVAFileFactory.sp_Files;
        }
    }

    public enum EVACommandType
    {
        // abort a running data transfer
        Abort,
        // compute CRC value for partition content
        CheckPartition,
        // get environment value
        GetEnvironmentValue,
        // set media type, see EVAMediaTypes
        MediaType,
        // terminate the control connection, logout the user
        Quit,
        // switch to passive transfer mode
        Passive,
        // switch to passive transfer mode, alternative version to fool proxy servers
        Passive_Alt,
        // send password of user
        Password,
        // reboot the device
        Reboot,
        // retrieve the content of a file, see EVAFiles
        Retrieve,
        // set environment value
        SetEnvironmentValue,
        // store data to flash or SDRAM memory
        Store,
        // get system type information
        SystemType,
        // data transfer mode, see EVADataMode
        Type,
        // remove an environment value
        UnsetEnvironmentValue,
        // set the user name for authentication
        User,
    }

    public class EVACommand
    {
        private EVACommandType p_CommandType;
        private string p_CommandValue;

        public EVACommand(EVACommandType CommandType, string CommandValue)
        {
            this.p_CommandType = CommandType;
            this.p_CommandValue = CommandValue;
        }

        public EVACommandType CommandType
        {
            get
            {
                return this.p_CommandType;
            }
        }

        public string CommandValue
        {
            get
            {
                return this.p_CommandValue;
            }
        }
    }

    public class EVACommands : System.Collections.Generic.Dictionary<EVACommandType, EVACommand>
    {
    }

    public class EVACommandFactory
    {
        static private EVACommands sp_Commands;

        public static EVACommands GetCommands()
        {
            if (EVACommandFactory.sp_Commands != null)
            {
                return EVACommandFactory.sp_Commands;
            }

            EVACommands cmds = new EVACommands();
            EVACommandFactory.sp_Commands = cmds;

            cmds.Add(EVACommandType.Abort, new EVACommand(EVACommandType.Abort, "ABOR"));
            cmds.Add(EVACommandType.CheckPartition, new EVACommand(EVACommandType.CheckPartition, "CHECK"));
            cmds.Add(EVACommandType.GetEnvironmentValue, new EVACommand(EVACommandType.GetEnvironmentValue, "GETENV"));
            cmds.Add(EVACommandType.MediaType, new EVACommand(EVACommandType.MediaType, "MEDIA"));
            cmds.Add(EVACommandType.Quit, new EVACommand(EVACommandType.Quit, "QUIT"));
            cmds.Add(EVACommandType.Passive, new EVACommand(EVACommandType.Passive, "PASV"));
            cmds.Add(EVACommandType.Passive_Alt, new EVACommand(EVACommandType.Passive_Alt, "P@SW"));
            cmds.Add(EVACommandType.Password, new EVACommand(EVACommandType.Password, "PASS"));
            cmds.Add(EVACommandType.Reboot, new EVACommand(EVACommandType.Reboot, "REBOOT"));
            cmds.Add(EVACommandType.Retrieve, new EVACommand(EVACommandType.Retrieve, "RETR"));
            cmds.Add(EVACommandType.SetEnvironmentValue, new EVACommand(EVACommandType.SetEnvironmentValue, "SETENV"));
            cmds.Add(EVACommandType.Store, new EVACommand(EVACommandType.Store, "STOR"));
            cmds.Add(EVACommandType.SystemType, new EVACommand(EVACommandType.SystemType, "SYST"));
            cmds.Add(EVACommandType.Type, new EVACommand(EVACommandType.Type, "TYPE"));
            cmds.Add(EVACommandType.UnsetEnvironmentValue, new EVACommand(EVACommandType.UnsetEnvironmentValue, "UNSETENV"));
            cmds.Add(EVACommandType.User, new EVACommand(EVACommandType.User, "USER"));

            return EVACommandFactory.sp_Commands;
        }
    }

    public enum EVAErrorSeverity
    {
        // no error
        Success,
        // continuation expected
        Continue,
        // temporary failure
        TemporaryFailure,
        // permanent failure, operation not started
        PermanentFailure,
    }

    public class EVAResponse
    {
        private EVAErrorSeverity p_Severity;
        private int p_Code;
        private string p_Message;

        public EVAResponse(int Code, string Message, EVAErrorSeverity Severity)
        {
            this.p_Code = Code;
            this.p_Message = Message;
            this.p_Severity = Severity;
        }

        public EVAResponse(int Code, string Message)
        {
            this.p_Code = Code;
            this.p_Message = Message;
            this.p_Severity = EVAErrorSeverity.PermanentFailure;
        }

        public EVAResponse(int Code, EVAErrorSeverity Severity)
        {
            this.p_Code = Code;
            this.p_Message = System.String.Empty;
            this.p_Severity = Severity;
        }

        public EVAResponse(int Code)
        {
            this.p_Code = Code;
            this.p_Message = System.String.Empty;
            this.p_Severity = EVAErrorSeverity.PermanentFailure;
        }

        public int Code
        {
            get
            {
                return this.p_Code;
            }
        }

        public string Message
        {
            get
            {
                return this.p_Message;
            }
        }

        public EVAErrorSeverity Severity
        {
            get
            {
                return this.p_Severity;
            }
        }
    }

    public class EVAResponses : System.Collections.Generic.List<EVAResponse>
    {
    }

    public class EVAResponseFactory
    {
        static private EVAResponses sp_Responses;

        public static EVAResponses GetResponses()
        {
            if (EVAResponseFactory.sp_Responses != null)
            {
                return EVAResponseFactory.sp_Responses;
            }

            EVAResponses resp = new EVAResponses();
            EVAResponseFactory.sp_Responses = resp;

            resp.Add(new EVAResponse(120, "Service not ready, please wait", EVAErrorSeverity.TemporaryFailure));
            resp.Add(new EVAResponse(150, "Opening BINARY data connection", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(150, "Opening ASCII data connection", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(150, "Flash check 0x{0:x}", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, "GETENV command successful", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, "SETENV command successful", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, "UNSETENV command successful", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, "Media set to {0:s}", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, "Type set to {0:s}", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(215, "AVM EVA Version {0:d}.{1:s} 0x{2:x} 0x{3:x}{4:s}", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(220, "ADAM2 FTP Server ready", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(221, "Goodbye", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(221, "Thank you for using the FTP service on ADAM2", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(226, "Transfer complete", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(227, "Entering Passive Mode ({0:d},{1:d},{2:d},{3:d},{4:d},{5:d})", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(230, "User {0:s} successfully logged in", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(331, "Password required for {0:s}", EVAErrorSeverity.Continue));
            resp.Add(new EVAResponse(425, "can`'nt open data connection"));
            resp.Add(new EVAResponse(426, "Data connection closed"));
            resp.Add(new EVAResponse(501, "environment variable not set"));
            resp.Add(new EVAResponse(501, "unknown variable {0:s}"));
            resp.Add(new EVAResponse(501, "store failed"));
            resp.Add(new EVAResponse(501, "Syntax error: Invalid number of parameters"));
            resp.Add(new EVAResponse(502, "Command not implemented"));
            resp.Add(new EVAResponse(505, "Close Data connection first"));
            resp.Add(new EVAResponse(530, "not logged in"));
            resp.Add(new EVAResponse(551, "unknown Mediatype"));
            resp.Add(new EVAResponse(553, "Urlader_Update failed."));
            resp.Add(new EVAResponse(553, "Flash erase failed."));
            resp.Add(new EVAResponse(553, "RETR failed."));
            resp.Add(new EVAResponse(553, "Execution failed."));

            return EVAResponseFactory.sp_Responses;
        }
    }

    public class FTPClientException : Exception
    {
        public FTPClientException()
        {
        }

        public FTPClientException(string message)
            : base(message)
        {
        }

        public FTPClientException(string message, Exception inner) : base(message, inner)
        {
        }
    }

    public class CommandSentEventArgs : EventArgs
    {
        private readonly string p_Line = String.Empty;
        private readonly DateTime p_SentAt = DateTime.Now;

        internal CommandSentEventArgs(string Line)
        {
            p_Line = Line;
        }

        public string Line
        {
            get
            {
                return p_Line;
            }
        }

        public DateTime SentAt
        {
            get
            {
                return p_SentAt;
            }
        }
    }

    public class ResponseReceivedEventArgs : EventArgs
    {
        private readonly string p_Line = String.Empty;
        private readonly DateTime p_ReceivedAt = DateTime.Now;

        internal ResponseReceivedEventArgs(string Line)
        {
            p_Line = Line;
        }

        public string Line
        {
            get
            {
                return p_Line;
            }
        }

        public DateTime ReceivedAt
        {
            get
            {
                return p_ReceivedAt;
            }
        }
    }

    public class ResponseCompletedEventArgs : EventArgs
    {
        private readonly FTPResponse p_Response;
        private readonly DateTime p_CompletedAt = DateTime.Now;

        internal ResponseCompletedEventArgs(FTPResponse Response)
        {
            p_Response = Response;
        }

        public FTPResponse Response
        {
            get
            {
                return p_Response;
            }
        }

        public DateTime CompletedAt
        {
            get
            {
                return p_CompletedAt;
            }
        }
    }

    public class ActionCompletedEventArgs : EventArgs
    {
        private readonly FTPAction p_Action;
        private readonly DateTime p_FinishedAt = DateTime.Now;

        internal ActionCompletedEventArgs(FTPAction Action)
        {
            p_Action = Action;
        }

        public FTPAction Action
        {
            get
            {
                return p_Action;
            }
        }

        public DateTime FinishedAt
        {
            get
            {
                return p_FinishedAt;
            }
        }
    }

    public class FTPResponse
    {
        private volatile TaskCompletionSource<FTPResponse> p_Task = new TaskCompletionSource<FTPResponse>();
        private int p_Code = -1;
        private string p_Message = String.Empty;
        private bool p_IsComplete = false;

        public FTPResponse()
        {
        }

        public FTPResponse(int Code)
        {
            p_Code = Code;
        }

        public FTPResponse(int Code, string Message)
        {
            p_Code = Code;
            p_Message = Message;
        }

        public bool IsComplete
        {
            get
            {
                return p_IsComplete;
            }
        }

        public virtual bool IsSingleLine
        {
            get
            {
                return true;
            }
        }

        public int Code
        {
            get
            {
                return p_Code;
            }
            internal set
            {
                p_Code = value;
            }
        }

        public string Message
        {
            get
            {
                return p_Message;
            }
        }

        public TaskCompletionSource<FTPResponse> AsyncTaskCompletionSource
        {
            get
            {
                return p_Task;
            }
        }

        public override string ToString()
        {
            return String.Format("{0:d} {1:s}", p_Code, p_Message);
        }

        protected void SetCompletion()
        {
            p_IsComplete = true;
            p_Task.SetResult(this);
        }

        protected void SetCompletion(Exception e)
        {
            p_IsComplete = true;
            p_Task.SetException(e);
        }
    }

    public class MultiLineResponse : FTPResponse
    {
        private List<string> p_Content = new List<string>();
        private string p_InitialMessage = String.Empty;
        private string p_FinalMessage = String.Empty;

        public MultiLineResponse() : base()
        {
        }

        public MultiLineResponse(string FirstContentLine) : base()
        {
            AppendLine(FirstContentLine);
        }

        public MultiLineResponse(string InitialMessage, int Code) : base(Code)
        {
            p_InitialMessage = InitialMessage;
        }

        public override bool IsSingleLine
        {
            get
            {
                return false;
            }
        }

        public List<string> Content
        {
            get
            {
                return p_Content;
            }
        }

        public string InitialMessage
        {
            get
            {
                return p_InitialMessage;
            }
        }

        public string FinalMessage
        {
            get
            {
                return p_FinalMessage;
            }
        }

        public void AppendLine(string Line)
        {
            lock (((ICollection)p_Content).SyncRoot)
            {
                p_Content.Add(Line);
            }
        }

        public void Finish(string FinalMessage, int Code)
        {
            if (base.Code != -1 && base.Code != Code)
            {
                base.SetCompletion(new FTPClientException(String.Format("Multi-line response was started with code {0} and finished with code {1} - a violation of RFC 959.", base.Code, Code)));
                return;
            }

            p_FinalMessage = FinalMessage;
            if (base.Code == -1) base.Code = Code;

            base.SetCompletion();
        }

        public override string ToString()
        {
            return String.Format("{0:d} {1:s}", base.Code, p_FinalMessage);
        }
    }

    public class FTPAction
    {
        private string p_Command = String.Empty;
        private volatile TaskCompletionSource<FTPAction> p_Task = new TaskCompletionSource<FTPAction>();
        private FTPResponse p_Response = new FTPResponse();
        private bool p_Aborted = false;

        public FTPAction()
        {
        }

        public FTPAction(string Command)
        {
            p_Command = Command;
        }

        public string Command
        {
            get
            {
                return p_Command;
            }
        }

        public FTPResponse Response
        {
            get
            {
                return p_Response;
            }
            internal set
            {
                p_Response = value;
            }
        }

        public bool Completed
        {
            get
            {
                return false;
            }
        }

        public Task<FTPAction> AsyncTask
        {
            get
            {
                return p_Task.Task;
            }
        }

        internal TaskCompletionSource<FTPAction> AsyncTaskCompletionSource
        {
            get
            {
                return p_Task;
            }
        }

        public bool Cancel()
        {
            // TODO: implement abortion of a running command
            lock (this)
            {
                if (!p_Response.IsComplete)
                {
                    p_Aborted = true;
                }
            }
            return p_Aborted;
        }

        public override string ToString()
        {
            return String.Format("{0:s}: {1:d} {2:s}", p_Command, p_Response.Code, p_Response.Message);
        }
    }

    public class FTPControlChannelReceiver
    {
        private Regex p_MatchResponse = new Regex(@"^(?<code>\d{3})(?<delimiter>[ \t-])(?<message>.*)$", RegexOptions.Compiled);
        private Queue<FTPResponse> p_ResponseQueue = new Queue<FTPResponse>();
        private FTPResponse p_CurrentResponse = null;

        public EventHandler<ResponseReceivedEventArgs> ResponseReceived;
        public EventHandler<ResponseCompletedEventArgs> ResponseCompleted;

        public FTPControlChannelReceiver()
        {
        }

        internal Queue<FTPResponse> Responses
        {
            get
            {
                return p_ResponseQueue;
            }
        }

        public void AddResponse(string Line)
        {
            MatchCollection matches = p_MatchResponse.Matches(Line);

            OnResponseReceived(Line);

            if (matches.Count > 0)
            {
                int code = -1;
                bool startMultiline = false;
                string message = String.Empty;

                foreach (Group match in matches[0].Groups)
                {
                    if (match.Name.CompareTo("code") == 0)
                    {
                        code = Convert.ToInt32(match.Value);
                    }
                    else if (match.Name.CompareTo("delimiter") == 0)
                    {
                        startMultiline = (match.Value.CompareTo("-") == 0);
                    }
                    else if (match.Name.CompareTo("message") == 0)
                    {
                        message = match.Value;
                    }
                }

                if (startMultiline)
                {
                    if (p_CurrentResponse != null && !p_CurrentResponse.IsSingleLine)
                    {
                        p_CurrentResponse.AsyncTaskCompletionSource.SetException(new FTPClientException(String.Format("Multi-line start message with code {0:d} (see RFC 959) after previous response lines.", code)));
                        return;
                    }
                    p_CurrentResponse = new MultiLineResponse(Line, code);
                }
                else if (!startMultiline)
                {
                    if (p_CurrentResponse != null)
                    {
                        ((MultiLineResponse)p_CurrentResponse).Finish(message, code);
                    }
                    else
                    {
                        p_CurrentResponse = new FTPResponse(code, message);
                    }

                    FTPResponse completed = p_CurrentResponse;
                    p_CurrentResponse = null;
                    lock (((ICollection)p_ResponseQueue).SyncRoot)
                    {
                        p_ResponseQueue.Enqueue(completed);
                    }

                    OnResponseCompleted(completed);
                }
            }
            else
            {
                if (p_CurrentResponse != null)
                {
                    ((MultiLineResponse)p_CurrentResponse).AppendLine(Line);
                }
                else
                {
                    p_CurrentResponse = new MultiLineResponse(Line);
                }
            }
        }

        public void Clear()
        {
            lock (((ICollection)p_ResponseQueue).SyncRoot)
            {
                p_ResponseQueue.Clear();
                p_CurrentResponse = null;
            }
        }

        protected void OnResponseReceived(string Line)
        {
            EventHandler<ResponseReceivedEventArgs> handler = ResponseReceived;
            if (handler != null)
            {
                handler(this, new ResponseReceivedEventArgs(Line));
            }
        }

        protected void OnResponseCompleted(FTPResponse Response)
        {
            EventHandler<ResponseCompletedEventArgs> handler = ResponseCompleted;
            try
            {
                if (handler != null)
                {
                    handler(this, new ResponseCompletedEventArgs(Response));
                }
                Response.AsyncTaskCompletionSource.SetResult(Response);
            }
            catch (Exception e)
            {
                Response.AsyncTaskCompletionSource.SetException(e);
            }
        }
    }

    // generic FTP client class
    public class FTPClient
    {
        public enum DataConnectionMode
        {
            Active = 1,
            Passive = 2,
        }

        public enum DataType
        {
            Text = 1,
            Binary = 2,
        }

        public event EventHandler<CommandSentEventArgs> CommandSent;
        public event EventHandler<ResponseReceivedEventArgs> ResponseReceived;
        public event EventHandler<ActionCompletedEventArgs> ActionCompleted;

        // properties fields
        private IPAddress p_Address = IPAddress.Any;
        private int p_Port = 21;
        private DataConnectionMode p_DataConnectionMode = DataConnectionMode.Passive;
        private string p_PassiveConnectionCommand = "P@SW";
        private DataType p_DataType = DataType.Binary;
        private int p_DataPort = 22;
        private int p_ConnectTimeout = 120000;
        private bool p_IsOpened = false;
        private bool p_OpenedDataConnection = false;
        private FTPAction p_CurrentAction = null;

        // solely private values, never exposed to others
        private TcpClient controlConnection = null;
        private StreamWriter controlWriter = null;
        private StreamReader controlReader = null;
        private FTPControlChannelReceiver controlChannelReceiver = null;
        private Task controlChannelReaderTask = null;

        public FTPClient()
        {
        }

        public FTPClient(string Address)
        {
            p_Address = IPAddress.Parse(Address);
        }

        public FTPClient(string Address, int Port)
        {
            p_Address = IPAddress.Parse(Address);
            this.Port = Port;
        }

        public FTPClient(IPAddress Address)
        {
            p_Address = Address;
        }

        public FTPClient(IPAddress Address, int Port)
        {
            p_Address = Address;
            this.Port = Port;
        }

        public IPAddress Address
        {
            get
            {
                return p_Address;
            }
        }

        public int Port
        {
            get
            {
                return p_Port;
            }
            internal set
            {
                if (value > 65534 || value < 1)
                {
                    throw new FTPClientException(String.Format("Invalid port number {0:s} specified.", Convert.ToString(value)));
                }
                p_Port = value;
            }
        }

        public DataConnectionMode ConnectionMode
        {
            get
            {
                return p_DataConnectionMode;
            }
            set
            {
                if (value != DataConnectionMode.Passive)
                {
                    throw new FTPClientException("Only passive transfer mode is implemented yet.");
                }

                p_DataConnectionMode = value;
            }
        }

        public string PassiveConnectionCommand
        {
            get
            {
                return p_PassiveConnectionCommand;
            }
            set
            {
                if (value.CompareTo("P@SW") != 0 && value.CompareTo("PASV") != 0)
                {
                    throw new FTPClientException("Only commands `'PASV`' and `'P@SW`' are supported.");
                }
                p_PassiveConnectionCommand = value;
            }
        }

        public DataType TransferType
        {
            get
            {
                return p_DataType;
            }
            set
            {
                if (value != DataType.Binary)
                {
                    throw new FTPClientException("Only binary transfers are supported yet.");
                }
                p_DataType = value;
            }
        }

        public int DataPort
        {
            get
            {
                return p_DataPort;
            }
            set
            {
                if (IsOpen)
                {
                    throw new FTPClientException("Data port may only be set on a closed connection.");
                }
                p_DataPort = value;
            }
        }

        public int ConnectTimeout
        {
            get
            {
                return p_ConnectTimeout;
            }
            set
            {
                p_ConnectTimeout = value;
            }
        }

        public bool IsOpen
        {
            get
            {
                bool opened;

                lock (this)
                {
                    opened = p_IsOpened;
                }

                return opened;
            }
        }

        public bool IsConnected
        {
            get
            {
                if (IsOpen)
                {
                    return controlConnection.Connected;
                }
                return false;
            }
        }

        public bool HasOpenDataConnection
        {
            get
            {
                return p_OpenedDataConnection;
            }
        }

        public FTPAction CurrentAction
        {
            get
            {
                return p_CurrentAction;
            }
        }

        public async Task Open()
        {
            await Open(p_Address, p_Port);
        }

        public async Task Open(string Address)
        {
            await Open(IPAddress.Parse(Address), p_Port);
        }

        public async Task Open(string Address, int Port)
        {
            await Open(IPAddress.Parse(Address), Port);
        }

        public async Task Open(IPAddress Address)
        {
            await Open(Address, p_Port);
        }

        public async Task Open(IPAddress Address, int Port)
        {
            if (IsOpen)
            {
                throw new FTPClientException("The connection is already opened.");
            }
            p_Address = Address;
            p_Port = Port;

            try
            {
                controlConnection = new TcpClient(p_Address.ToString(), p_Port);
            }
            catch (SocketException e)
            {
                throw new FTPClientException("Error connecting to FTP server.", e);
            }

            controlWriter = OpenWriter(controlConnection);
            controlChannelReceiver = new FTPControlChannelReceiver();
            controlChannelReceiver.ResponseReceived += OnControlChannelResponseReceived;
            controlChannelReceiver.ResponseCompleted += OnControlChannelResponseCompleted;
            controlReader = OpenReader(controlConnection);

            controlChannelReaderTask = Task.Run(async () => { await AsyncControlReader(controlReader, controlChannelReceiver); });

            Task waitForConnection = Task.Run(async () => { while (!IsOpen) await Task.Delay(10); });

            await Task.CompletedTask;

            if (!waitForConnection.Wait(p_ConnectTimeout)) throw new FTPClientException(String.Format("Timeout connecting to FTP server at {0:s}:{1:d}.", p_Address, p_Port));
        }

        public async virtual void Close()
        {
            bool waitForCompletion = false;

            lock (this)
            {
                if (p_CurrentAction != null)
                {
                    if (p_CurrentAction.Cancel())
                    {
                        controlWriter.WriteLine("ABOR");
                        waitForCompletion = true;
                    }
                }
            }
            if (waitForCompletion)
            {
                try
                {
                    await CurrentAction.AsyncTask;
                }
                catch
                {
                    // ignore any exception during close
                }
            }

            lock (this)
            {
                p_IsOpened = false;
            }

            if (controlReader != null)
            {
                controlReader.Dispose();
                controlReader = null;
            }

            if (controlWriter != null)
            {
                controlWriter.Dispose();
                controlWriter = null;
            }

            if (controlChannelReceiver != null)
            {
                controlChannelReceiver.Clear();
                controlChannelReceiver = null;
            }

            if (controlConnection != null)
            {
                try
                {
                    controlConnection.GetStream().Dispose();
                    controlConnection.Close();
                    controlConnection.Dispose();
                }
                catch (InvalidOperationException)
                {
                }
                controlConnection = null;
            }
        }

        public FTPResponse NextResponse()
        {
            FTPResponse nextResponse = null;

            lock (((ICollection)controlChannelReceiver.Responses).SyncRoot)
            {
                if (controlChannelReceiver.Responses.Count > 0)
                {
                    nextResponse = controlChannelReceiver.Responses.Dequeue();
                }
            }

            return nextResponse;
        }

        public void ClearResponses()
        {
            controlChannelReceiver.Clear();
        }

        public FTPAction StartAction(string Command)
        {
            if (!IsOpen)
            {
                throw new FTPClientException("Unable to issue a command on a closed client connection.");
            }

            if (Command.CompareTo("ABOR") == 0)
            {
                if (p_CurrentAction == null)
                {
                    throw new FTPClientException("There is no command in progress, which could get aborted.");
                }
            }
            else
            {
                if (p_CurrentAction != null)
                {
                    throw new FTPClientException("There is already a command in progress.");
                }
                // remove any garbage from previous command, if the new one is not an ABOR command
                controlChannelReceiver.Clear();
            }

            p_CurrentAction = new FTPAction(Command);

            OnCommandSent(p_CurrentAction.Command);

            try
            {
                // start the new command
                controlWriter.WriteLine(p_CurrentAction.Command);
            }
            catch (Exception e)
            {
                Debug.WriteLine("FTPClient.StartCommand - Exception occured: {0:s}", e.Message);
                p_CurrentAction.AsyncTaskCompletionSource.SetException(e);
            }

            return p_CurrentAction;
        }

        protected void DataCommandCompleted()
        {
            p_OpenedDataConnection = false;
//            OnControlCommandCompleted();
        }

        protected virtual void OnCommandSent(string Line)
        {
            EventHandler<CommandSentEventArgs> handler = CommandSent;
            if (handler != null)
            {
                handler(this, new CommandSentEventArgs(Line));
            }
        }

        protected virtual void OnResponseReceived(ResponseReceivedEventArgs e)
        {
            EventHandler<ResponseReceivedEventArgs> handler = ResponseReceived;
            if (handler != null)
            {
                handler(this, e);
            }
        }

        protected virtual void OnActionCompleted(FTPAction Action)
        {
            EventHandler<ActionCompletedEventArgs> handler = ActionCompleted;
            try
            {
                if (handler != null)
                {
                    handler(this, new ActionCompletedEventArgs(Action));
                }

                Action.AsyncTaskCompletionSource.SetResult(Action);
            }
            catch (Exception e)
            {
                Action.AsyncTaskCompletionSource.SetException(e);
            }
        }

        private StreamWriter OpenWriter(TcpClient connection)
        {
            StreamWriter writer = new StreamWriter(connection.GetStream(), Encoding.ASCII)
            {
                NewLine = "\r\n",
                AutoFlush = true
            };
            return writer;
        }

        private StreamReader OpenReader(TcpClient connection)
        {
            return new StreamReader(connection.GetStream(), Encoding.ASCII);
        }

        private async Task AsyncControlReader(StreamReader reader, FTPControlChannelReceiver receiver)
        {
            do
            {
                string readLine = null;

                try
                {
                    readLine = await reader.ReadLineAsync();
                    if (readLine != null) receiver.AddResponse(readLine);
                }
                catch (Exception e)
                {
                    Debug.WriteLine(String.Format("AsyncControlReader - Exception: {0:s}", e.Message));
                }

                if (readLine == null) await Task.Delay(10);
            } while (controlConnection.Connected);
        }

        private void OnControlCommandCompleted(FTPResponse Response)
        {
            FTPAction lastAction = null;

            lock (this)
            {
                if (p_CurrentAction != null)
                {
                    lastAction = p_CurrentAction;
                }
                p_CurrentAction = null;
            }

            if (lastAction != null)
            {
                lastAction.Response = Response;
                OnActionCompleted(lastAction);
            }
        }

        private void OnControlChannelResponseReceived(Object sender, ResponseReceivedEventArgs e)
        {
            OnResponseReceived(e);
        }

        private void OnControlChannelResponseCompleted(Object sender, ResponseCompletedEventArgs e)
        {
            switch (e.Response.Code)
            {
                case 150:
                    lock (this)
                    {
                        p_OpenedDataConnection = true;
                    }
                    return;

                case 220:
                    lock (this)
                    {
                        p_IsOpened = true;
                    }
                    return;

                case 421:
                    lock (this)
                    {
                        p_IsOpened = false;
                        controlConnection.Close();
                    }
                    return;

                default:
                    OnControlCommandCompleted(e.Response);
                    break;
            }
        }
    }

    // EVA specific exception
    public class EVAClientException : Exception
    {
        public EVAClientException()
        {
        }

        public EVAClientException(string message)
            : base(message)
        {
        }

        public EVAClientException(string message, Exception inner) : base(message, inner)
        {
        }
    }

    // EVA specific FTP client class
    public class EVAClient : FTPClient
    {
        // static initial settings
        public readonly static string EVADefaultIP = "192.168.178.1";

        private bool p_IsLoggedIn = false;

        public EVAClient() :
            base(EVAClient.EVADefaultIP)
        {
            Initialize();
        }

        public EVAClient(string Address) :
            base(Address)
        {
            Initialize();
        }

        public EVAClient(string Address, int Port) :
            base(Address, Port)
        {
            Initialize();
        }

        public EVAClient(IPAddress Address) :
            base(Address)
        {
            Initialize();
        }

        public EVAClient(IPAddress Address, int Port) :
            base(Address, Port)
        {
            Initialize();
        }

        public bool IsLoggedIn
        {
            get
            {
                return p_IsLoggedIn;
            }
        }

        public async override void Close()
        {
            if (IsLoggedIn)
            {
                await Logout();
            }

            base.Close();
        }

        public async Task<FTPAction> RunCommand(string Command)
        {
            return await StartAction(Command).AsyncTask;
        }

        public async Task Login()
        {
            p_IsLoggedIn = true;
            await Task.Yield();
        }

        public async Task Logout()
        {
            p_IsLoggedIn = false;
            await Task.Yield();
        }

        private void Initialize()
        {
            base.ActionCompleted += EVAClient.OnActionCompleted;
        }

        private static void OnActionCompleted(Object sender, ActionCompletedEventArgs e)
        {
            switch (e.Action.Response.Code)
            {
                case 530:
                    e.Action.AsyncTaskCompletionSource.SetException(new EVAClientException("Login needed."));
                    break;

                default:
                    break;
            }
        }
    }

    public class TestFTPClient
    {
        static void Main(string[] args)
        {
            TestFTPClient.Run(args);
        }

        static async void Run(string[] args)
        {
            EVAClient eva = new EVAClient();
            FTPAction action;

            eva.CommandSent += CommandSent;
            eva.ResponseReceived += ResponseReceived;
            eva.ActionCompleted += ActionCompleted;

            try
            {
                await eva.Open("192.168.130.1");

                Task<FTPAction> actionTask = eva.RunCommand("LIST");

                action = await actionTask;

                //Console.WriteLine("Command       : {0:s}", "LIST");
                //Console.WriteLine("AsyncResponse : {0:d} {1:s}", action.Response.Code, action.Response.Message);
                //if (!action.Response.IsSingleLine)
                //{
                //    ((MultiLineResponse)action.Response).Content.ForEach(action: (line) => Console.WriteLine("              : {0:s}", line));
                //}
            }
            catch (YourFritz.EVA.FTPClientException e)
            {
                Debug.WriteLine(String.Format("Main: {0:s}", e.ToString()));
            }
            catch (YourFritz.EVA.EVAClientException e)
            {
                Debug.WriteLine(String.Format("Main: {0:s}", e.ToString()));
            }
            catch (Exception e)
            {
                Debug.WriteLine(String.Format("Main: {0:s}", e.ToString()));
            }

            eva.Close();
        }

        static void CommandSent(Object sender, CommandSentEventArgs e)
        {
            Debug.WriteLine(String.Format("Main - Sending command: {0:s}", e.Line));
            Console.WriteLine("< {0:s}", e.Line);
        }

        static void ResponseReceived(Object sender, ResponseReceivedEventArgs e)
        {
            Debug.WriteLine(String.Format("Main - Response received: {0:s}", e.Line));
            Console.WriteLine("> {0:s}", e.Line);
        }

        static void ActionCompleted(Object source, ActionCompletedEventArgs e)
        {
            Debug.WriteLine(String.Format("Main - Action completed: {0:s} => {1:s}",e.Action.Command, e.Action.Response.ToString()));
            Console.WriteLine("Command : {0:s}", e.Action.Command);
            Console.WriteLine("Response: {0:s}", e.Action.Response.ToString());
            if (!e.Action.Response.IsSingleLine)
            {
                ((MultiLineResponse)e.Action.Response).Content.ForEach(action: (line) => Console.WriteLine("        : {0:s}", line));
            }
        }
    }

    public class UdpPacket
    {
        public enum Direction
        {
            Request = 1,
            Answer = 2,
        }

        public IPAddress Address { get; }
        public Direction PacketType { get; }

        internal UdpPacket()
        {
            this.PacketType = Direction.Request;
            this.Address = new IPAddress(0);
        }

        internal UdpPacket(IPAddress requestedIP)
        {
            this.PacketType = Direction.Request;
            this.Address = requestedIP;
        }

        internal UdpPacket(byte[] answer)
        {
            this.PacketType = (Direction)answer[4];
            if ((this.PacketType == Direction.Answer) && (answer[2] == 18) && (answer[3] == 1))
            {
                byte[] address = new byte[4] { answer[11], answer[10], answer[9], answer[8] };
                this.Address = new IPAddress(address);
            }
            else
            {
                throw new DiscoveryException("Unexpected packet type found in received data.");
            }
        }

        public bool Equals(UdpPacket other)
        {
            if (this.PacketType == other.PacketType && this.Address.Equals(other.Address))
            {
                return true;
            }
            return false;
        }

        public byte[] ToBytes()
        {
            byte[] output = new byte[16];

            output[2] = 18;
            output[3] = 1;
            output[4] = Convert.ToByte(this.PacketType);
            this.Address.GetAddressBytes().CopyTo(output, 8);

            return output;
        }

        public static bool IsAnswer(byte[] data)
        {
            if (data[2] == 18 && data[3] == 1 && data[4] == (byte)Direction.Answer)
            {
                return true;
            }
            return false;
        }
    }

    public class Device
    {
        public IPAddress Address { get; }
        public int Port { get; }

        internal Device(IPEndPoint ep, UdpPacket answer)
        {
            if (answer.PacketType != UdpPacket.Direction.Answer)
            {
                throw new DiscoveryException("The specified UDP packet isn't a discovery response.");
            }

            if (!answer.Address.Equals(ep.Address))
            {
                throw new DiscoveryException("The IP address in the received packet does not match the packet sender's address.");
            }

            this.Address = ep.Address;
            this.Port = ep.Port;
        }
    }

    public class StartEventArgs : EventArgs
    {
        public IPAddress Address { get; }
        public int Port { get; }
        public DateTime StartedAt { get; }

        internal StartEventArgs(IPAddress address, int port)
        {
            this.Address = address;
            this.Port = port;
            this.StartedAt = DateTime.Now;
        }
    }

    public class StopEventArgs : EventArgs
    {
        public int DeviceCount { get; }
        public DateTime StoppedAt { get; }

        internal StopEventArgs(int count)
        {
            this.DeviceCount = count;
            this.StoppedAt = DateTime.Now;
        }
    }

    public class PacketSentEventArgs : EventArgs
    {
        public IPAddress Address { get; }
        public int Port { get; }
        public DateTime SentAt { get; }
        public byte[] SentData { get; }

        internal PacketSentEventArgs(IPAddress address, int port, byte[] data)
        {
            this.Address = address;
            this.Port = port;
            this.SentData = data;
            this.SentAt = DateTime.Now;
        }
    }

    public class PacketReceivedEventArgs : EventArgs
    {
        public IPEndPoint EndPoint { get; }
        public DateTime ReceivedAt { get; }
        public byte[] ReceivedData { get; }

        internal PacketReceivedEventArgs(IPEndPoint ep, byte[] data)
        {
            this.EndPoint = ep;
            this.ReceivedData = data;
            this.ReceivedAt = DateTime.Now;
        }
    }

    public class DeviceFoundEventArgs : EventArgs
    {
        public Device Device { get; }
        public DateTime FoundAt { get; }

        internal DeviceFoundEventArgs(Device Device)
        {
            this.Device = Device;
            this.FoundAt = DateTime.Now;
        }
    }

    public class DiscoveryException : Exception
    {
        public DiscoveryException()
        {
        }

        public DiscoveryException(string message)
            : base(message)
        {
        }

        public DiscoveryException(string message, Exception inner) : base(message, inner)
        {
        }
    }

    public class Discovery
    {
        // default FRITZ!Box IP address
        public IPAddress BoxIP { get; set; } = new IPAddress(new byte[] { 192, 168, 178, 1 });
        // default broadcast address to use - any other value requires access to SocketOptions
        public IPAddress BroadcastAddress { get; set; } = new IPAddress(new byte[] { 255, 255, 255, 255 });
        // the UDP port to sent to/receive from
        public int DiscoveryPort { get; set; } = 5035;
        // the discovered devices
        public Dictionary<IPAddress, Device> FoundDevices { get; } = new Dictionary<IPAddress, Device>();
        // discovery active flag
        public bool IsRunning { get; internal set; } = false;

        // the UDP packet for discovery
        private UdpPacket sendData = new UdpPacket();
        // the listener receiving any response
        private UdpClient listener = null;
        // the client used to send UDP broadcast packets
        private UdpClient sender = null;
        // the timer used to send one packet per second
        private Timer sendTimer = null;
        // event to set, if we're waiting for discovery to get finished
        private System.Threading.ManualResetEvent stopEvent = null;
        // stop on first device found
        private bool stopOnFirstDeviceFound = false;

        // events raised by this class
        public EventHandler<StartEventArgs> Started;
        public EventHandler<StopEventArgs> Stopped;
        public EventHandler<PacketSentEventArgs> PacketSent;
        public EventHandler<PacketReceivedEventArgs> PacketReceived;
        public EventHandler<DeviceFoundEventArgs> DeviceFound;

        public Discovery()
        {
            this.sendData = new UdpPacket(this.BoxIP);
        }

        ~Discovery()
        {
            if (this.sendTimer != null)
            {
                this.sendTimer.Stop();
                this.sendTimer.Dispose();
                this.sendTimer = null;
            }

            if (this.sender != null)
            {
                this.sender.Close();
                this.sender.Dispose();
                this.sender = null;
            }

            if (this.listener != null)
            {
                this.listener.Close();
                this.listener.Dispose();
                this.listener = null;
            }
        }

        public void Start(IPAddress newIP)
        {
            if (this.IsRunning)
            {
                throw new DiscoveryException("Discovery is already running.");
            }

            if (newIP != null)
            {
                if (!newIP.Equals(this.BoxIP))
                {
                    this.BoxIP = newIP;
                }
                this.sendData = new UdpPacket(newIP);
            }
            else
            {
                this.sendData = new UdpPacket(new IPAddress(0));
            }

            if (this.sender == null)
            {
                this.sender = new UdpClient();
            }

            if (this.listener == null)
            {
                this.listener = new UdpClient(this.DiscoveryPort);
            }
            this.listener.BeginReceive(new AsyncCallback(UdpListenerCallback), this);

            if (this.stopEvent != null)
            {
                this.stopEvent.Reset();
            }

            if (this.sendTimer == null)
            {
                this.sendTimer = new Timer();
                this.sendTimer.Interval = 100;
                this.sendTimer.Elapsed += SendTimer_Elapsed;
            }
            this.sendTimer.Start();

            this.IsRunning = true;
            this.OnStartDiscovery(this.BoxIP, this.DiscoveryPort);
        }

        public void Start(string requestedIP)
        {
            IPAddress newIP;

            if (requestedIP != null && requestedIP.Length > 0)
            {
                newIP = IPAddress.Parse(requestedIP);
            }
            else
            {
                newIP = new IPAddress(0);
            }
            this.Start(newIP);
        }

        public void Start()
        {
            this.Start(this.BoxIP);
        }

        public void Restart(IPAddress newIP)
        {
            if (this.IsRunning)
            {
                this.Stop();
            }
            this.Start(newIP);
        }

        public void Restart(string newIP)
        {
            if (this.IsRunning)
            {
                this.Stop();
            }
            this.Start(newIP);
        }

        public void Restart()
        {
            this.Restart(this.BoxIP);
        }

        public void Stop()
        {
            if (this.IsRunning)
            {
                this.IsRunning = false;
                this.OnStopDiscovery(this.FoundDevices.Count);
            }
            if (this.sendTimer != null)
            {
                this.sendTimer.Stop();
            }
            if (this.stopEvent != null)
            {
                this.stopEvent.Set();
            }
        }

        public Device[] WaitUntilFinished(bool StopOnDeviceFound, int WaitMax)
        {
            int timeout = System.Threading.Timeout.Infinite;

            if (this.stopEvent == null)
            {
                this.stopEvent = new System.Threading.ManualResetEvent(false);
            }
            if (WaitMax != System.Threading.Timeout.Infinite)
            {
                timeout = WaitMax * 1000;
            }
            this.stopOnFirstDeviceFound = StopOnDeviceFound;
            this.stopEvent.WaitOne(timeout);

            Device[] found = new Device[this.FoundDevices.Count];
            int index = 0;
            foreach (Device dev in this.FoundDevices.Values)
            {
                found[index++] = dev;
            }
            return found;
        }

        public Device[] WaitUntilFinished(int WaitMax)
        {
            return this.WaitUntilFinished(false, WaitMax);
        }

        private void SendTimer_Elapsed(object sender, ElapsedEventArgs e)
        {
            if (!this.IsRunning)
            {
                return;
            }

            byte[] data = this.sendData.ToBytes();
            IPEndPoint ep = new IPEndPoint(this.BroadcastAddress, this.DiscoveryPort);
            this.sender.Send(data, data.Length, ep);

            this.OnPacketSent(this.BoxIP, this.DiscoveryPort, data);

            if (this.IsRunning)
            {
                this.sendTimer.Interval = 1000;
                this.sendTimer.Start();
            }
        }

        protected virtual void OnStartDiscovery(IPAddress address, int port)
        {
            EventHandler<StartEventArgs> handler = this.Started;
            if (handler != null) handler(this, new StartEventArgs(address, port));
        }

        protected virtual void OnStopDiscovery(int count)
        {
            EventHandler<StopEventArgs> handler = this.Stopped;
            if (handler != null) handler(this, new StopEventArgs(count));
        }

        protected virtual void OnPacketSent(IPAddress address, int port, byte[] data)
        {
            EventHandler<PacketSentEventArgs> handler = this.PacketSent;
            if (handler != null) handler(this, new PacketSentEventArgs(address, port, data));
        }

        protected virtual void OnPacketReceived(IPEndPoint ep, byte[] data)
        {
            EventHandler<PacketReceivedEventArgs> handler = this.PacketReceived;
            if (handler != null) handler(this, new PacketReceivedEventArgs(ep, data));
        }

        protected virtual void OnDeviceFound(Device newDevice)
        {
            EventHandler<DeviceFoundEventArgs> handler = this.DeviceFound;
            if (handler != null) handler(this, new DeviceFoundEventArgs(newDevice));
            if (this.stopOnFirstDeviceFound)
            {
                this.Stop();
            }
        }

        private static void UdpListenerCallback(IAsyncResult asyncRes)
        {
            Discovery discovery = (Discovery)asyncRes.AsyncState;
            IPEndPoint ep = new IPEndPoint(IPAddress.Any, discovery.DiscoveryPort);
            byte[] received = discovery.listener.EndReceive(asyncRes, ref ep);

            try
            {
                if (UdpPacket.IsAnswer(received))
                {
                    discovery.OnPacketReceived(ep, received);

                    UdpPacket recvData = new UdpPacket(received);
                    Device foundDevice = new Device(ep, recvData);
                    if (!discovery.FoundDevices.ContainsKey(foundDevice.Address))
                    {
                        discovery.FoundDevices.Add(foundDevice.Address, foundDevice);
                        discovery.OnDeviceFound(foundDevice);
                    }
                }
            }
            catch (DiscoveryException)
            {
            }
            finally
            {
                if (discovery.IsRunning)
                {
                    discovery.listener.BeginReceive(new AsyncCallback(UdpListenerCallback), discovery);
                }
            }
        }
    }

    public class Discover
    {
        static void Main(string[] args)
        {
            Discovery disco = new Discovery();

            disco.DeviceFound += DeviceFound;
            disco.Started += Started;
            disco.Stopped += Stopped;
            disco.PacketSent += Blip;
            disco.Start("192.168.178.9");
            Device[] found = disco.WaitUntilFinished(true, 120);
            Console.WriteLine("Number of devices found: {0}", found.Length);
            foreach (Device dev in found)
            {
                Console.WriteLine("EVA found at {0} ...", dev.Address);
            }
            disco.Restart("192.168.178.8");
            found = disco.WaitUntilFinished(false, 10);
            Console.WriteLine("Number of devices found: {0}", found.Length);
            foreach (Device dev in found)
            {
                Console.WriteLine("EVA found at {0} ...", dev.Address);
            }
        }

        static void DeviceFound(Object sender, DeviceFoundEventArgs e)
        {
            Console.WriteLine("Device found at {0}:{1:d}", e.Device.Address.ToString(), e.Device.Port);
        }

        static void Started(Object sender, StartEventArgs e)
        {
            Console.WriteLine("Device discovery started, IP address will be set to {0} ...", e.Address.ToString());
        }

        static void Stopped(Object sender, StopEventArgs e)
        {
            Console.WriteLine("Device discovery finished.");
        }

        static void Blip(Object sender, PacketSentEventArgs e)
        {
            Console.WriteLine("Sending UDP discovery packet ...");
        }
    }
}
'@;
}

Get-TypeData -TypeName YourFritz.EVA.Discovery