// SPDX-License-Identifier: GPL-2.0-or-later
using System;
using System.Collections.Generic;
using System.Text;

namespace YourFritz.TFFS
{
    public class TFFSHelpers
    {
        private TFFSHelpers() { }

        // combine two or more byte array to one single bigger-one
        internal static byte[] CombineByteArrays(byte[][] inputArrays)
        {
            // count combined length of all arrays
            int count = 0;
            Array.ForEach<byte[]>(inputArrays, delegate (byte[] buffer) { count += buffer.Length; });

            byte[] output = new byte[count];
            count = 0;

            Array.ForEach<byte[]>(inputArrays, delegate (byte[] buffer) { Array.Copy(buffer, 0, output, count, buffer.Length); count += buffer.Length; });

            return output;
        }

        // TFFS uses big endian order for numbers, get the bytes for a 32-bit value
        internal static byte[] GetBytesBE(int input)
        {
            byte[] output = BitConverter.GetBytes(input);

            if (BitConverter.IsLittleEndian)
            {
                Array.Reverse(output, 0, sizeof(int));
            }

            return output;
        }

        // TFFS uses big endian order for numbers, get the bytes for a 16-bit value
        internal static byte[] GetBytesBE(UInt16 input)
        {
            byte[] output = BitConverter.GetBytes(input);

            if (BitConverter.IsLittleEndian)
            {
                Array.Reverse(output, 0, sizeof(UInt16));
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
        GPON_Serial = 457,
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
        private string p_Name = String.Empty;
        private TFFSEnvironmentID p_ID = TFFSEnvironmentID.Free;

        public TFFSEnvironmentEntry(TFFSEnvironmentID ID, string Name)
        {
            p_ID = ID;
            p_Name = Name;
        }

        public TFFSEnvironmentID ID
        {
            get
            {
                return p_ID;
            }
        }

        public string Name
        {
            get
            {
                return p_Name;
            }
        }

        public override bool Equals(object obj)
        {
            return (((TFFSEnvironmentEntry)obj).Name.CompareTo(p_Name) == 0) && (((TFFSEnvironmentEntry)obj).ID == p_ID);
        }

        public override int GetHashCode()
        {
            return new { p_ID, p_Name }.GetHashCode();
        }

        public byte[] ImageBytes
        {
            get
            {
                byte[] name = Encoding.ASCII.GetBytes(p_Name);
                byte[] aligned = new byte[((name.Length + 1) + 3) & ~3];
                Array.Copy(name, aligned, name.Length);
                return TFFSHelpers.CombineByteArrays(new byte[][] { TFFSHelpers.GetBytesBE((int)p_ID), aligned });
            }
        }
    }

    public class TFFSEnvironmentEntries : Dictionary<TFFSEnvironmentID, TFFSEnvironmentEntry>
    {
        public TFFSEnvironmentEntry[] ToArray()
        {
            TFFSEnvironmentEntry[] output = new TFFSEnvironmentEntry[Count];
            int index = 0;

            foreach(TFFSEnvironmentEntry e in Values)
            {
                output[index++] = e;
            }

            return output;
        }
    }

    public class TFFSEntryFactory
    {
        static private TFFSEnvironmentEntries sp_Entries;

        private TFFSEntryFactory() { }

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
            entries.Add(TFFSEnvironmentID.GPON_Serial, new TFFSEnvironmentEntry(TFFSEnvironmentID.GPON_Serial, "gpon_serial"));
            entries.Add(TFFSEnvironmentID.Removed, new TFFSEnvironmentEntry(TFFSEnvironmentID.Removed, "zuende"));

            return TFFSEntryFactory.sp_Entries;
        }
    }

    public class TFFSNameTableEntries : List<TFFSEnvironmentID>
    {
    }

    public class TFFSNameTable
    {
        private TFFSEnvironmentEntry p_Version;
        private TFFSEnvironmentEntries p_Entries = new TFFSEnvironmentEntries();
        private TFFSNameTableEntries p_Order = new TFFSNameTableEntries();

        public TFFSNameTable(string Version, TFFSNameTableEntries Entries)
        {
            p_Version = new TFFSEnvironmentEntry(TFFSEnvironmentID.NameTableVersion, Version);
            foreach (TFFSEnvironmentID entry in Entries)
            {
                p_Entries.Add(entry, (TFFSEntryFactory.GetEntries()[entry]));
            }
            p_Order = Entries;
        }

        public string Version
        {
            get
            {
                return p_Version.Name;
            }
        }

        public TFFSEnvironmentEntries Entries
        {
            get
            {
                return p_Entries;
            }
        }

        // get a buffer with table in image format - the kernel uses fix-sized entries (with 64 bytes length for the name)
        public byte[] ImageBytes
        {
            get
            {
                // we start with our version entry
                byte[] output = p_Version.ImageBytes;

                // and append each other entry in the correct order
                p_Order.ForEach(id => output = TFFSHelpers.CombineByteArrays(new byte[][] { output, p_Entries[id].ImageBytes }));

                // prepend it with the correct environment ID and length of the table
                output = TFFSHelpers.CombineByteArrays(new byte[][] { TFFSHelpers.GetBytesBE((UInt16)TFFSEnvironmentID.NameTableID), TFFSHelpers.GetBytesBE((UInt16)output.Length), output });

                return output;
            }
        }

        public TFFSEnvironmentID FindID(string Name)
        {
            foreach(TFFSEnvironmentEntry e in Entries.Values)
            {
                if (e.Name.CompareTo(Name) == 0)
                {
                    return e.ID;
                }
            }

            return TFFSEnvironmentID.Free;
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
                Version.CompareTo("@L") != 0 &&
                Version.CompareTo("@N") != 0)
            {
                throw new TFFSException("Only name table versions from @G (used in 2010) to @N (current) are supported yet.");
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

            if (Version.CompareTo("@L") == 1)
            {
                // gpon_serial was added in @N
                entries.Add(TFFSEnvironmentID.GPON_Serial);
            }

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

        // get the latest implemented name table
        public static TFFSNameTable GetLatest()
        {
            return TFFSNameTable.GetNameTable("@N");
        }
    }
}
