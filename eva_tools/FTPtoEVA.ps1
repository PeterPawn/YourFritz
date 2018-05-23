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
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;
using YourFritz.TFFS;

namespace YourFritz.EVA
{
    public class EVAConstants
    {
        // static initial settings
        public readonly static string EVADefaultIP = "192.168.178.1";
        public readonly static int EVADefaultDiscoveryPort = 5035;
        public readonly static string EVADefaultUser = "adam2";
        public readonly static string EVADefaultPassword = "adam2";
        public readonly static int EVADiscoveryTimeout = 120;
    }

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
            p_Type = MediaType;
            p_Name = Name;
        }

        public EVAMediaType MediaType
        {
            get
            {
                return p_Type;
            }
        }

        public string Name
        {
            get
            {
                return p_Name;
            }
        }
    }

    public class EVAMediaDictionary : Dictionary<EVAMediaType, EVAMedia>
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
            p_Mode = DataMode;
            p_Name = Name;
        }

        public EVADataMode DataMode
        {
            get
            {
                return p_Mode;
            }
        }

        public string Name
        {
            get
            {
                return p_Name;
            }
        }
    }

    public class EVADataModeValues : Dictionary<EVADataMode, EVADataModeValue>
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
            p_Type = FileType;
            p_Name = Name;
        }

        public EVAFileType FileType
        {
            get
            {
                return p_Type;
            }
        }

        public string Name
        {
            get
            {
                return p_Name;
            }
        }
    }

    public class EVAFiles : List<EVAFile>
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
            p_CommandType = CommandType;
            p_CommandValue = CommandValue;
        }

        public EVACommandType CommandType
        {
            get
            {
                return p_CommandType;
            }
        }

        public string CommandValue
        {
            get
            {
                return p_CommandValue;
            }
        }
    }

    public class EVACommands : Dictionary<EVACommandType, EVACommand>
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
            cmds.Add(EVACommandType.CheckPartition, new EVACommand(EVACommandType.CheckPartition, "CHECK {0:s}"));
            cmds.Add(EVACommandType.GetEnvironmentValue, new EVACommand(EVACommandType.GetEnvironmentValue, "GETENV {0:s}"));
            cmds.Add(EVACommandType.MediaType, new EVACommand(EVACommandType.MediaType, "MEDIA {0:s}"));
            cmds.Add(EVACommandType.Quit, new EVACommand(EVACommandType.Quit, "QUIT"));
            cmds.Add(EVACommandType.Passive, new EVACommand(EVACommandType.Passive, "PASV"));
            cmds.Add(EVACommandType.Passive_Alt, new EVACommand(EVACommandType.Passive_Alt, "P@SW"));
            cmds.Add(EVACommandType.Password, new EVACommand(EVACommandType.Password, "PASS {0:s}"));
            cmds.Add(EVACommandType.Reboot, new EVACommand(EVACommandType.Reboot, "REBOOT"));
            cmds.Add(EVACommandType.Retrieve, new EVACommand(EVACommandType.Retrieve, "RETR {0:s}"));
            cmds.Add(EVACommandType.SetEnvironmentValue, new EVACommand(EVACommandType.SetEnvironmentValue, "SETENV {0:s} {1:s}"));
            cmds.Add(EVACommandType.Store, new EVACommand(EVACommandType.Store, "STOR {0:s}"));
            cmds.Add(EVACommandType.SystemType, new EVACommand(EVACommandType.SystemType, "SYST"));
            cmds.Add(EVACommandType.Type, new EVACommand(EVACommandType.Type, "TYPE {0:s}"));
            cmds.Add(EVACommandType.UnsetEnvironmentValue, new EVACommand(EVACommandType.UnsetEnvironmentValue, "UNSETENV {0:s}"));
            cmds.Add(EVACommandType.User, new EVACommand(EVACommandType.User, "USER {0:s}"));

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

    [Flags]
    public enum EVAResponseFlags
    {
        ClosesConnection = 16,
        ClosesDataConnection = 2,
        DataConnectionParameters = 2048,
        GoodbyeMessage = 8,
        Identity = 1024,
        LoggedIn = 256,
        None = 0,
        NotImplemented = 32,
        NotLoggedIn = 64,
        PasswordRequired = 128,
        StartsDataConnection = 1,
        WelcomeMessage = 4,
        WrongMultiLineResponse = 512,
    }

    public class EVAResponse
    {
        private EVAErrorSeverity p_Severity = EVAErrorSeverity.PermanentFailure;
        private int p_Code;
        private string p_Message = String.Empty;
        private string p_RegexMask = String.Empty;
        private string[] p_RegexMatches = new string[0];
        private Regex p_Match;
        private EVAResponseFlags p_Flags = EVAResponseFlags.None;

        public EVAResponse(int Code, EVAResponseFlags Flags, string Message, EVAErrorSeverity Severity, string RegexMask, string[] RegexMatches)
        {
            p_Code = Code;
            p_Flags = Flags;
            p_Message = Message;
            p_Severity = Severity;
            p_RegexMask = RegexMask;
            p_RegexMatches = RegexMatches;
            p_Match = new Regex(p_RegexMask, RegexOptions.Compiled & RegexOptions.CultureInvariant & RegexOptions.ExplicitCapture);
        }

        public EVAResponse(int Code, EVAResponseFlags Flags, string Message, EVAErrorSeverity Severity)
        {
            p_Code = Code;
            p_Flags = Flags;
            p_Message = Message;
            p_Severity = Severity;
        }

        public EVAResponse(int Code, EVAResponseFlags Flags, string Message, string RegexMask, string[] RegexMatches)
        {
            p_Code = Code;
            p_Flags = Flags;
            p_Message = Message;
            p_RegexMask = RegexMask;
            p_RegexMatches = RegexMatches;
            p_Match = new Regex(p_RegexMask, RegexOptions.Compiled & RegexOptions.CultureInvariant & RegexOptions.ExplicitCapture);
        }

        public EVAResponse(int Code, EVAResponseFlags Flags, string Message)
        {
            p_Code = Code;
            p_Flags = Flags;
            p_Message = Message;
        }

        public EVAResponse(int Code, EVAResponseFlags Flags, EVAErrorSeverity Severity, string RegexMask, string[] RegexMatches)
        {
            p_Code = Code;
            p_Flags = Flags;
            p_Severity = Severity;
            p_RegexMask = RegexMask;
            p_RegexMatches = RegexMatches;
            p_Match = new Regex(p_RegexMask, RegexOptions.Compiled & RegexOptions.CultureInvariant & RegexOptions.ExplicitCapture);
        }

        public EVAResponse(int Code, EVAResponseFlags Flags, EVAErrorSeverity Severity)
        {
            p_Code = Code;
            p_Flags = Flags;
            p_Severity = Severity;
        }

        public EVAResponse(int Code)
        {
            p_Code = Code;
        }

        public int Code
        {
            get
            {
                return p_Code;
            }
        }

        public string Message
        {
            get
            {
                return p_Message;
            }
        }

        public EVAErrorSeverity Severity
        {
            get
            {
                return p_Severity;
            }
        }

        public string RegexMask
        {
            get
            {
                return p_RegexMask;
            }
        }

        public string[] RegexMatches
        {
            get
            {
                return p_RegexMatches;
            }
        }

        public Regex Regex
        {
            get
            {
                return p_Match;
            }
        }

        public EVAResponseFlags Flags
        {
            get
            {
                return p_Flags;
            }
        }
    }

    public class EVAResponses : List<EVAResponse>
    {
        public List<EVAResponse> GetResponses(int Code)
        {
            List<EVAResponse> output = new List<EVAResponse>();

            ForEach((r) =>
            {
                if (r.Code == Code)
                {
                    output.Add(r);
                }
            });

            return output;
        }

        public EVAResponse FindResponse(int Code, string Message)
        {
            foreach(EVAResponse r in this)
            {
                if (r.Code == Code)
                {
                    if (r.Regex == null)
                    {
                        if (r.Message.CompareTo(Message) == 0)
                        {
                            return r;
                        }
                    }
                    else
                    {
                        Match found = r.Regex.Match(Message);

                        if (found.Success)
                        {
                            return r;
                        }
                    }
                }
            }

            return null;
        }
    }

    public class EVAResponseFactory
    {
        static private EVAResponses sp_Responses;

        private EVAResponseFactory() { }

        public static EVAResponses GetResponses()
        {
            if (EVAResponseFactory.sp_Responses != null)
            {
                return EVAResponseFactory.sp_Responses;
            }

            EVAResponses resp = new EVAResponses();
            EVAResponseFactory.sp_Responses = resp;

            resp.Add(new EVAResponse(120, EVAResponseFlags.None, @"Service not ready, please wait", EVAErrorSeverity.TemporaryFailure));
            resp.Add(new EVAResponse(150, EVAResponseFlags.None & EVAResponseFlags.StartsDataConnection, @"Opening BINARY data connection", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(150, EVAResponseFlags.None & EVAResponseFlags.StartsDataConnection, @"Opening ASCII data connection", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(150, EVAResponseFlags.None, @"Flash check 0x{0:x}", EVAErrorSeverity.Success, @"^Flash check 0x(?<value>[0-9a-fA-F]*)$", new string[] { "value" }));
            resp.Add(new EVAResponse(200, EVAResponseFlags.None & EVAResponseFlags.WrongMultiLineResponse, @"GETENV command successful", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, EVAResponseFlags.None, @"SETENV command successful", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, EVAResponseFlags.None, @"UNSETENV command successful", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(200, EVAResponseFlags.None, @"Media set to {0:s}", EVAErrorSeverity.Success, @"^Media set to (?<mediatype>.*)$", new string[] { "mediatype" }));
            resp.Add(new EVAResponse(200, EVAResponseFlags.None, @"Type set to {0:s}", EVAErrorSeverity.Success, @"^Type set to (?<type>.*)$", new string[] { "type" }));
            resp.Add(new EVAResponse(215, EVAResponseFlags.None & EVAResponseFlags.Identity, @"AVM EVA Version {0:d}.{1:s} 0x{2:x} 0x{3:x}{4:s}", EVAErrorSeverity.Success, @"^AVM EVA Version (?<version>.*) .*$", new string[] { "version" }));
            resp.Add(new EVAResponse(220, EVAResponseFlags.None & EVAResponseFlags.WelcomeMessage, @"ADAM2 FTP Server ready", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(221, EVAResponseFlags.None & EVAResponseFlags.GoodbyeMessage, @"Goodbye", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(221, EVAResponseFlags.None & EVAResponseFlags.GoodbyeMessage, @"Thank you for using the FTP service on ADAM2", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(226, EVAResponseFlags.None & EVAResponseFlags.ClosesDataConnection, @"Transfer complete", EVAErrorSeverity.Success));
            resp.Add(new EVAResponse(227, EVAResponseFlags.None & EVAResponseFlags.DataConnectionParameters, @"Entering Passive Mode ({0:d},{1:d},{2:d},{3:d},{4:d},{5:d})", EVAErrorSeverity.Success, @"^Entering Passive Mode \(((?<b>[0-9]{1,3}),?){6}\)$", new string[] { "b" }));
            resp.Add(new EVAResponse(230, EVAResponseFlags.None & EVAResponseFlags.LoggedIn, @"User {0:s} successfully logged in", EVAErrorSeverity.Success, @"^User (?<user>.*) successfully logged in$", new string[] { "user" }));
            resp.Add(new EVAResponse(331, EVAResponseFlags.None & EVAResponseFlags.PasswordRequired, @"Password required for {0:s}", EVAErrorSeverity.Continue, @"^Password required for (?<user>.*)$", new string[] { "user" }));
            resp.Add(new EVAResponse(425, EVAResponseFlags.None, @"can'nt open data connection"));
            resp.Add(new EVAResponse(426, EVAResponseFlags.None & EVAResponseFlags.ClosesDataConnection, @"Data connection closed"));
            resp.Add(new EVAResponse(501, EVAResponseFlags.None, @"environment variable not set"));
            resp.Add(new EVAResponse(501, EVAResponseFlags.None, @"unknown variable {0:s}", EVAErrorSeverity.PermanentFailure, @"^unknown variable (?<var>.*)$", new string[] { "var" }));
            resp.Add(new EVAResponse(501, EVAResponseFlags.None & EVAResponseFlags.ClosesDataConnection, @"store failed"));
            resp.Add(new EVAResponse(501, EVAResponseFlags.None, @"Syntax error: Invalid number of parameters"));
            resp.Add(new EVAResponse(502, EVAResponseFlags.None & EVAResponseFlags.NotImplemented, @"Command not implemented"));
            resp.Add(new EVAResponse(505, EVAResponseFlags.None, @"Close Data connection first"));
            resp.Add(new EVAResponse(530, EVAResponseFlags.None & EVAResponseFlags.NotLoggedIn, @"not logged in"));
            resp.Add(new EVAResponse(551, EVAResponseFlags.None, @"unknown Mediatype"));
            resp.Add(new EVAResponse(553, EVAResponseFlags.None, @"Urlader_Update failed."));
            resp.Add(new EVAResponse(553, EVAResponseFlags.None, @"Flash erase failed."));
            resp.Add(new EVAResponse(553, EVAResponseFlags.None & EVAResponseFlags.ClosesDataConnection, @"RETR failed."));
            resp.Add(new EVAResponse(553, EVAResponseFlags.None & EVAResponseFlags.ClosesDataConnection, @"Execution failed."));

            return EVAResponseFactory.sp_Responses;
        }
    }

    internal class DiscoveryUdpPacket
    {
        internal enum Direction
        {
            Request = 1,
            Answer = 2,
        }

        private IPAddress p_Address = new IPAddress(0);
        private Direction p_PacketType = Direction.Request;

        internal DiscoveryUdpPacket()
        {
        }

        internal DiscoveryUdpPacket(IPAddress requestedIP)
        {
            p_Address = requestedIP;
        }

        internal DiscoveryUdpPacket(byte[] answer)
        {
            p_PacketType = (Direction)answer[4];
            if ((p_PacketType == Direction.Answer) && (answer[2] == 18) && (answer[3] == 1))
            {
                byte[] address = new byte[4] { answer[11], answer[10], answer[9], answer[8] };
                p_Address = new IPAddress(address);
            }
            else
            {
                throw new EVADiscoveryException("Unexpected packet type found in received data.");
            }
        }

        internal IPAddress Address
        {
            get
            {
                return p_Address;
            }
        }

        internal Direction PacketType
        {
            get
            {
                return p_PacketType;
            }
        }

        internal bool Equals(DiscoveryUdpPacket other)
        {
            return (p_PacketType == other.p_PacketType) && (p_Address.Equals(other.p_Address));
        }

        internal byte[] ToBytes()
        {
            byte[] output = new byte[16];

            output[2] = 18;
            output[3] = 1;
            output[4] = Convert.ToByte(p_PacketType);
            p_Address.GetAddressBytes().CopyTo(output, 8);

            return output;
        }

        internal static bool IsAnswer(byte[] data)
        {
            return (data[2] == 18) && (data[3] == 1) && (data[4] == (byte)Direction.Answer);
        }
    }

    public class EVADevice
    {
        private IPAddress p_Address;
        private int p_Port;

        internal EVADevice(IPEndPoint ep, DiscoveryUdpPacket answer)
        {
            if (answer.PacketType != DiscoveryUdpPacket.Direction.Answer)
            {
                throw new EVADiscoveryException("The specified UDP packet isn't a discovery response.");
            }

            if (!answer.Address.Equals(ep.Address))
            {
                throw new EVADiscoveryException("The IP address in the received packet does not match the packet sender's address.");
            }

            p_Address = ep.Address;
            p_Port = ep.Port;
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
        }
    }

    public class EVADevices : Dictionary<IPAddress, EVADevice>
    {
    }

    public class DiscoveryStartEventArgs : EventArgs
    {
        private IPAddress p_Address;
        private int p_Port;
        private DateTime p_StartedAt = DateTime.Now;

        internal DiscoveryStartEventArgs(IPAddress address, int port)
        {
            p_Address = address;
            p_Port = port;
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
        }

        public DateTime StartedAt
        {
            get
            {
                return p_StartedAt;
            }
        }
    }

    public class DiscoveryStopEventArgs : EventArgs
    {
        private int p_DeviceCount = 0;
        private bool p_Canceled = false;
        private DateTime p_StoppedAt = DateTime.Now;

        internal DiscoveryStopEventArgs(int Count, bool Canceled)
        {
            p_DeviceCount = Count;
            p_Canceled = Canceled;
        }

        public int DeviceCount
        {
            get
            {
                return p_DeviceCount;
            }
        }

        public bool Canceled
        {
            get
            {
                return p_Canceled;
            }
        }

        public DateTime StoppedAt
        {
            get
            {
                return p_StoppedAt;
            }
        }
    }

    public class DiscoveryPacketSentEventArgs : EventArgs
    {
        private IPAddress p_Address;
        private int p_Port;
        private byte[] p_SentData;
        private DateTime p_SentAt = DateTime.Now;

        internal DiscoveryPacketSentEventArgs(IPAddress address, int port, byte[] data)
        {
            p_Address = address;
            p_Port = port;
            p_SentData = data;
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
        }

        public byte[] SentData
        {
            get
            {
                return p_SentData;
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

    public class DiscoveryPacketReceivedEventArgs : EventArgs
    {
        private IPEndPoint p_EndPoint;
        private byte[] p_ReceivedData;
        private DateTime p_ReceivedAt = DateTime.Now;

        internal DiscoveryPacketReceivedEventArgs(IPEndPoint ep, byte[] data)
        {
            p_EndPoint = ep;
            p_ReceivedData = data;
        }

        public IPEndPoint EndPoint
        {
            get
            {
                return p_EndPoint;
            }
        }

        public byte[] ReceivedData
        {
            get
            {
                return p_ReceivedData;
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

    public class DiscoveryDeviceFoundEventArgs : EventArgs
    {
        private EVADevice p_Device;
        private DateTime p_FoundAt = DateTime.Now;

        internal DiscoveryDeviceFoundEventArgs(EVADevice Device)
        {
            p_Device = Device;
        }

        public EVADevice Device
        {
            get
            {
                return p_Device;
            }
        }

        public DateTime FoundAt
        {
            get
            {
                return p_FoundAt;
            }
        }
    }

    public class EVADiscoveryException : Exception
    {
        internal EVADiscoveryException()
        {
        }

        internal EVADiscoveryException(string message) : base(message)
        {
        }

        internal EVADiscoveryException(string message, Exception inner) : base(message, inner)
        {
        }
    }

    public class EVADiscovery
    {
        private IPAddress p_BoxIP = IPAddress.Parse(EVAConstants.EVADefaultIP);
        private IPAddress p_BroadcastAddress = IPAddress.Broadcast;
        private int p_DiscoveryPort = EVAConstants.EVADefaultDiscoveryPort;
        private bool p_IsRunning = false;
        private bool p_Canceled = false;
        private int p_Timeout = EVAConstants.EVADiscoveryTimeout;
        private bool p_TimeoutElapsed = false;
        private bool p_StopOnFirstFound = false;

        private CancellationTokenSource ctSource = null;
        private TaskCompletionSource<EVADevices> discovery;

        public EventHandler<DiscoveryStartEventArgs> Started;
        public EventHandler<DiscoveryStopEventArgs> Stopped;
        public EventHandler<DiscoveryPacketSentEventArgs> PacketSent;
        public EventHandler<DiscoveryPacketReceivedEventArgs> PacketReceived;
        public EventHandler<DiscoveryDeviceFoundEventArgs> DeviceFound;

        public EVADiscovery()
        {
        }

        public IPAddress BoxIP
        {
            get
            {
                return p_BoxIP;
            }
            internal set
            {
                this.p_BoxIP = value;
            }
        }

        public IPAddress BroadcastAddress
        {
            get
            {
                return p_BroadcastAddress;
            }
        }

        public int DiscoveryPort
        {
            get
            {
                return p_DiscoveryPort;
            }
            internal set
            {
                if (value > 65534 || value < 1024)
                {
                    throw new FTPClientException(String.Format("Invalid port number {0:s} specified.", Convert.ToString(value)));
                }
                p_DiscoveryPort = value;
            }
        }

        public bool StopOnFirstFound
        {
            get
            {
                return p_StopOnFirstFound;
            }
            set
            {
                p_StopOnFirstFound = value;
            }
        }

        public int DiscoveryTimeout
        {
            get
            {
                return p_Timeout;
            }
            set
            {
                p_Timeout = value;
            }
        }

        public bool IsRunning
        {
            get
            {
                return p_IsRunning;
            }
        }

        public bool WasCanceled
        {
            get
            {
                return p_Canceled;
            }
        }

        public bool HasTimedOut
        {
            get
            {
                return p_TimeoutElapsed;
            }
        }

        public async Task<EVADevices> StartAsync(IPAddress newIP)
        {
            if (!p_IsRunning)
            {
                p_IsRunning = true;
            }
            else
            {
                throw new EVADiscoveryException("Discovery is already running.");
            }

            IPAddress sendAddress = p_BoxIP;

            if (newIP != null)
            {
                if (!newIP.Equals(p_BoxIP))
                {
                    p_BoxIP = newIP;
                    sendAddress = p_BoxIP;
                }
            }
            else
            {
                sendAddress = new IPAddress(0);
            }

            OnStartDiscovery(sendAddress, p_DiscoveryPort);

            EVADevices foundDevices = new EVADevices();
            discovery = new TaskCompletionSource<EVADevices>();

            ctSource = new CancellationTokenSource();

            List<Task> netIOTasks = new List<Task>
            {
                // listening task
                // do not use the cancellation token here, because socket operations are hard to abort
                // instead we'll receive our own packet and terminate the loop, if cancellation was requested
                Task.Factory.StartNew(() =>
                {
                    using (UdpClient listener = new UdpClient(p_DiscoveryPort))
                    {
                        IPEndPoint ep = new IPEndPoint(IPAddress.Any, p_DiscoveryPort);
                        bool canceled = false;

//                      Debug.WriteLine(String.Format("Listener started, task id = {0:d}", Task.CurrentId));

                        while (!canceled)
                        {
                            byte[] data = listener.Receive(ref ep);
                            if (DiscoveryUdpPacket.IsAnswer(data))
                            {
                                OnPacketReceived(ep, data);

                                EVADevice foundDevice = new EVADevice(ep, new DiscoveryUdpPacket(data));

                                if (!foundDevices.ContainsKey(foundDevice.Address))
                                {
                                    foundDevices.Add(foundDevice.Address, foundDevice);

                                    OnDeviceFound(foundDevice);

                                    if (p_StopOnFirstFound)
                                    {
                                        //Debug.WriteLine(String.Format("Answer received, leaving task {0:d} ...", Task.CurrentId));
                                        canceled = true;
                                    }
                                }
                            }
                            else
                            {
                                //Debug.WriteLine("Received sent broadcast packet ...");
                            }

                            if (ctSource.IsCancellationRequested)
                            {
                                canceled = true;
                            }
                        }
                    }
                }),

                // broadcast discovery packets, do not use cancellation token for the outer loop
                Task.Factory.StartNew(async () =>
                {
                    IPEndPoint ep = new IPEndPoint(p_BroadcastAddress, p_DiscoveryPort);
                    byte[] data = new DiscoveryUdpPacket(sendAddress).ToBytes();
                    int delay = 10;

                    //Debug.WriteLine(String.Format("Packet sender task, id = {0:d}", Task.CurrentId));

                    using (UdpClient sender = new UdpClient())
                    {
                        bool canceled = false;

                        while (!canceled)
                        {
                            try
                            {
                                await Task.Delay(delay, ctSource.Token);
                            }
                            catch (TaskCanceledException)
                            {
                            }

                            if (!ctSource.IsCancellationRequested)
                            {
                                sender.Send(data, data.Length, ep);

                                //Debug.WriteLine(String.Format("Packet sent"));

                                OnPacketSent(sendAddress, p_DiscoveryPort, data);

                                delay = 1000;
                            }
                            else
                            {
                                canceled = true;
                            }
                        }
                        //Debug.WriteLine(String.Format("Sending loop left"));

                        // send one more packet to terminate listening loop
                        sender.Send(data, data.Length, ep);
                        //Debug.WriteLine(String.Format("Final packet sent"));
                    }

                }),

                // timeout task, cancelable
                Task.Delay(DiscoveryTimeout * 1000, ctSource.Token).ContinueWith((t) =>
                {
                    p_TimeoutElapsed = true;
                    ctSource.Cancel();
                }, TaskContinuationOptions.NotOnCanceled)
            };

            while (netIOTasks.Count > 0)
            {
                try
                {
                    Task finished = await Task.WhenAny(netIOTasks);

                    //Debug.WriteLine(String.Format("Task {0:d} finished", finished.Id));

                    netIOTasks.Remove(finished);

                    if (finished is Task<Task> && !p_TimeoutElapsed)
                    {
                        netIOTasks.Add(((Task<Task>)finished).Result);
                    }
                    else
                    {
                        if (!ctSource.IsCancellationRequested && p_TimeoutElapsed)
                        {
                            ctSource.Cancel();
                        }
                    }
                }
                catch (TaskCanceledException e)
                {
                    netIOTasks.Remove(e.Task);
                }
                catch (AggregateException age)
                {
                    foreach (Exception e in age.InnerExceptions)
                    {
                        if (e is TaskCanceledException)
                        {
                            Task t = ((TaskCanceledException)e).Task;

                            if (netIOTasks.Count > 0 && netIOTasks.Contains(t))
                            {
                                netIOTasks.Remove(t);
                            }
                        }
                        else
                        {
                            throw e;
                        }
                    }
                }
                catch (Exception e)
                {
                    throw e;
                }
            }

            OnStopDiscovery(foundDevices.Count, p_Canceled);

            p_IsRunning = false;

            discovery.SetResult(foundDevices);

            return foundDevices;
        }

        public async Task<EVADevices> StartAsync(string requestedIP)
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

            return await StartAsync(newIP);
        }

        public async Task<EVADevices> StartAsync()
        {
            return await StartAsync(p_BoxIP);
        }

        public async Task CancelAsync()
        {
            if (p_IsRunning)
            {
                p_Canceled = true;
                ctSource.Cancel();
            }

            await Task.CompletedTask;
        }

        protected virtual void OnStartDiscovery(IPAddress address, int port)
        {
            EventHandler<DiscoveryStartEventArgs> handler = Started;
            if (handler != null)
            {
                handler(this, new DiscoveryStartEventArgs(address, port));
            }
        }

        protected virtual void OnStopDiscovery(int count, bool canceled)
        {
            EventHandler<DiscoveryStopEventArgs> handler = Stopped;
            if (handler != null)
            {
                handler(this, new DiscoveryStopEventArgs(count, canceled));
            }
        }

        protected virtual void OnPacketSent(IPAddress address, int port, byte[] data)
        {
            EventHandler<DiscoveryPacketSentEventArgs> handler = PacketSent;
            if (handler != null)
            {
                handler(this, new DiscoveryPacketSentEventArgs(address, port, data));
            }
        }

        protected virtual void OnPacketReceived(IPEndPoint ep, byte[] data)
        {
            EventHandler<DiscoveryPacketReceivedEventArgs> handler = PacketReceived;
            if (handler != null)
            {
                handler(this, new DiscoveryPacketReceivedEventArgs(ep, data));
            }
        }

        protected virtual void OnDeviceFound(EVADevice newDevice)
        {
            EventHandler<DiscoveryDeviceFoundEventArgs> handler = DeviceFound;
            if (handler != null)
            {
                handler(this, new DiscoveryDeviceFoundEventArgs(newDevice));
            }
        }
    }

    public class FTPClientException : Exception
    {
        internal FTPClientException()
        {
        }

        internal FTPClientException(string message)
            : base(message)
        {
        }

        internal FTPClientException(string message, Exception inner) : base(message, inner)
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
        private volatile TaskCompletionSource<FTPResponse> p_Task = new TaskCompletionSource<FTPResponse>(TaskCreationOptions.AttachedToParent);
        private int p_Code = -1;
        private string p_Message = String.Empty;
        private bool p_IsComplete = false;

        internal FTPResponse()
        {
        }

        internal FTPResponse(int Code)
        {
            p_Code = Code;
        }

        internal FTPResponse(int Code, string Message)
        {
            p_Code = Code;
            p_Message = Message;
        }

        internal FTPResponse(FTPResponse source)
        {
            p_Code = source.Code;
            p_Message = source.Message;
            p_IsComplete = source.IsComplete;
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

        internal TaskCompletionSource<FTPResponse> AsyncTaskCompletionSource
        {
            get
            {
                return p_Task;
            }
        }

        public virtual FTPResponse Clone()
        {
            if (this is MultiLineResponse)
            {
                return ((MultiLineResponse)this).Clone();
            }
            else
            {
                return new FTPResponse(this);
            }
        }

        public override string ToString()
        {
            return String.Format("{0:d} {1:s}", p_Code, p_Message);
        }

        internal void SetCompletion()
        {
            p_IsComplete = true;
            p_Task.SetResult(this);
        }

        internal void SetCompletion(Exception e)
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

        internal MultiLineResponse() : base()
        {
        }

        internal MultiLineResponse(string FirstContentLine) : base()
        {
            AppendLine(FirstContentLine);
        }

        internal MultiLineResponse(string InitialMessage, int Code) : base(Code)
        {
            p_InitialMessage = InitialMessage;
        }

        private MultiLineResponse(MultiLineResponse source) : base(source)
        {
            p_Content = new List<string>(source.Content);
            p_InitialMessage = source.InitialMessage;
            p_FinalMessage = source.FinalMessage;
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

        internal void AppendLine(string Line)
        {
            lock (p_Content)
            {
                p_Content.Add(Line);
            }
        }

        internal void Finish(string FinalMessage, int Code)
        {
            if (base.Code != -1 && base.Code != Code)
            {
                base.SetCompletion(new FTPClientException(String.Format("Multi-line response was started with code {0:d} and finished with code {1:d} - a violation of RFC 959.", base.Code, Code)));
                return;
            }

            p_FinalMessage = FinalMessage;
            if (base.Code == -1) base.Code = Code;

            base.SetCompletion();
        }

        public override FTPResponse Clone()
        {
            return new MultiLineResponse(this);
        }

        public override string ToString()
        {
            return String.Format("{0:d} {1:s}", base.Code, p_FinalMessage);
        }
    }

    public class FTPAction
    {
        private string p_Command = String.Empty;
        private volatile TaskCompletionSource<FTPAction> p_Task = new TaskCompletionSource<FTPAction>(TaskCreationOptions.AttachedToParent);
        private FTPResponse p_Response = new FTPResponse();
        private bool p_Aborted = false;
        private bool p_Success = false;
        private int p_ExpectedAnswer = 0;
        private readonly object p_Lock = new object();

        internal FTPAction()
        {
        }

        internal FTPAction(string Command)
        {
            p_Command = Command;
        }

        internal FTPAction(string Command, int ExpectedCode)
        {
            p_Command = Command;
            p_ExpectedAnswer = ExpectedCode;
        }

        private FTPAction(FTPAction source)
        {
            p_Command = source.Command;
            p_Response = source.Response.Clone();
            p_Aborted = source.Aborted;
            p_Success = source.Success;
            p_ExpectedAnswer = source.ExpectedAnswer;
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

        public bool Success
        {
            get
            {
                return p_Success;
            }
        }

        public int ExpectedAnswer
        {
            get
            {
                return p_ExpectedAnswer;
            }
            internal set
            {
                p_ExpectedAnswer = value;
            }
        }

        internal Task<FTPAction> AsyncTask
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

        private bool Aborted
        {
            get
            {
                return p_Aborted;
            }
        }

        public object SyncRoot
        {
            get
            {
                return p_Lock;
            }
        }

        public bool Cancel()
        {
            // TODO: implement abortion of a running command
            lock (SyncRoot)
            {
                if (!p_Response.IsComplete)
                {
                    p_Aborted = true;
                }
            }
            return p_Aborted;
        }

        public FTPAction Clone()
        {
            return new FTPAction(this);
        }

        public override string ToString()
        {
            return String.Format("{0:s}: {1:d} {2:s}", p_Command, p_Response.Code, p_Response.Message);
        }

        internal void CheckSuccess()
        {
            if (p_Response.Code == p_ExpectedAnswer)
            {
                p_Success = true;
            }
        }
    }

    internal class FTPControlChannelReceiver
    {
        private Regex p_MatchResponse = new Regex(@"^(?<code>\d{3})(?<delimiter>[ \t-])(?<message>.*)$", RegexOptions.Compiled);
        private Queue<FTPResponse> p_ResponseQueue = new Queue<FTPResponse>();
        private FTPResponse p_CurrentResponse = null;
        private bool p_CloseNow = false;
        private readonly object p_Lock = new object();

        public EventHandler<ResponseReceivedEventArgs> ResponseReceived;
        public EventHandler<ResponseCompletedEventArgs> ResponseCompleted;

        internal FTPControlChannelReceiver()
        {
        }

        internal Queue<FTPResponse> Responses
        {
            get
            {
                return p_ResponseQueue;
            }
        }

        internal bool CloseNow
        {
            get
            {
                return p_CloseNow;
            }
        }

        internal object SyncRoot
        {
            get
            {
                return p_Lock;
            }
        }

        internal async Task AddResponse(string Line)
        {
            MatchCollection matches = p_MatchResponse.Matches(Line);

            await OnResponseReceived(Line);

            if (matches.Count > 0)
            {
                int code = -1;
                bool startMultiline = false;
                string message = String.Empty;

                code = Convert.ToInt32(matches[0].Groups[1].Value);
                startMultiline = matches[0].Groups[2].Value.CompareTo("-") == 0;
                message = matches[0].Groups[3].Value;

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
                    lock (p_ResponseQueue)
                    {
                        p_ResponseQueue.Enqueue(completed);
                    }

                    await OnResponseCompleted(completed);
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

        internal void Clear()
        {
            lock (p_ResponseQueue)
            {
                p_ResponseQueue.Clear();
                p_CurrentResponse = null;
            }
        }

        internal void SetException(Exception e)
        {
            FTPResponse response = new FTPResponse(500, "Client error");
            response.AsyncTaskCompletionSource.SetException(e);
            lock (p_ResponseQueue)
            {
                p_ResponseQueue.Enqueue(response);
            }
        }

        internal void Close()
        {
            lock(SyncRoot)
            {
                p_CloseNow = true;
            }
        }

        protected async Task OnResponseReceived(string Line)
        {
            await Task.CompletedTask;

            EventHandler<ResponseReceivedEventArgs> handler = ResponseReceived;
            if (handler != null)
            {
                try
                {
                    handler(this, new ResponseReceivedEventArgs(Line));
                }
                catch
                {
                    // no exceptions from event handlers
                }
            }

            await Task.CompletedTask;
        }

        protected async Task OnResponseCompleted(FTPResponse Response)
        {
            await Task.CompletedTask;

            EventHandler<ResponseCompletedEventArgs> handler = ResponseCompleted;
            try
            {
                if (handler != null)
                {
                    handler(this, new ResponseCompletedEventArgs(Response));
                }
                if (!Response.AsyncTaskCompletionSource.Task.IsCompleted)
                {
                    Response.AsyncTaskCompletionSource.SetResult(Response);
                }
            }
            catch (Exception e)
            {
                if (!Response.AsyncTaskCompletionSource.Task.IsCompleted)
                {
                    Response.AsyncTaskCompletionSource.SetException(e);
                }
            }

            await Task.CompletedTask;
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
        private string[] p_PassiveConnectionCommands = new string[] { "PASV", "P@SW" };
        private string p_PassiveConnectionCommand = "PASV";
        private DataType p_DataType = DataType.Binary;
        private int p_DataPort = 22;
        private int p_ConnectTimeout = 120000;
        private bool p_IsOpened = false;
        private bool p_OpenedDataConnection = false;
        private FTPAction p_CurrentAction = null;
        private bool p_ForciblyClosed = false;
        private string p_AbortTransferCommand = "ABOR";
        protected readonly object p_Lock = new object();

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

        protected string[] PassiveConnectionCommands
        {
            get
            {
                return p_PassiveConnectionCommands;
            }
            set
            {
                p_PassiveConnectionCommands = value;
            }
        }

        protected string PassiveConnectionCommand
        {
            get
            {
                return p_PassiveConnectionCommand;
            }
            set
            {
                bool found = false;

                Array.ForEach(p_PassiveConnectionCommands, (c) =>
                {
                    if (c.CompareTo(value) == 0)
                    {
                        found = true;
                    }
                });

                if (!found)
                {
                    throw new FTPClientException(String.Format("The specified command '{0:s}' is not supported.", value));
                }

                p_PassiveConnectionCommand = value;
            }
        }

        protected string AbortTransferCommand
        {
            get
            {
                return p_AbortTransferCommand;
            }
            set
            {
                p_AbortTransferCommand = value;
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

                lock (SyncRoot)
                {
                    opened = p_IsOpened;
                }

                return opened;
            }
        }

        public bool IsClosedByServer
        {
            get
            {
                return p_ForciblyClosed;
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

        protected virtual object SyncRoot
        {
            get
            {
                return p_Lock;
            }
        }

        public virtual async Task OpenAsync()
        {
            await OpenAsync(p_Address, p_Port);
        }

        public virtual async Task OpenAsync(string Address)
        {
            await OpenAsync(IPAddress.Parse(Address), p_Port);
        }

        public virtual async Task OpenAsync(string Address, int Port)
        {
            await OpenAsync(IPAddress.Parse(Address), Port);
        }

        public virtual async Task OpenAsync(IPAddress Address)
        {
            await OpenAsync(Address, p_Port);
        }

        public virtual async Task OpenAsync(IPAddress Address, int Port)
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

            controlWriter = await OpenWriter(controlConnection);
            controlChannelReceiver = new FTPControlChannelReceiver();
            controlChannelReceiver.ResponseReceived += OnControlChannelResponseReceived;
            controlChannelReceiver.ResponseCompleted += OnControlChannelResponseCompleted;
            controlReader = await OpenReader(controlConnection);

            controlChannelReaderTask = Task.Run(async () => { await AsyncControlReader(controlReader, controlChannelReceiver); });

            Task waitForConnection = Task.Run(async () => { while (!IsOpen) await Task.Delay(10); });

            await Task.CompletedTask;

            if (!waitForConnection.Wait(p_ConnectTimeout)) throw new FTPClientException(String.Format("Timeout connecting to FTP server at {0:s}:{1:d}.", p_Address, p_Port));
        }

        public async virtual Task CloseAsync()
        {
            bool waitForCompletion = false;

            if (p_CurrentAction != null && !p_CurrentAction.AsyncTask.IsCompleted)
            {
                if (p_CurrentAction.Cancel())
                {
                    FTPAction abort = new FTPAction(p_AbortTransferCommand);
                    await WriteCommandAsync(abort);
                    waitForCompletion = true;
                }
            }

            if (waitForCompletion)
            {
                try
                {
                    await p_CurrentAction.AsyncTask;
                }
                catch
                {
                    // ignore any exception during close
                }
            }

            await Task.CompletedTask;

            lock (SyncRoot)
            {
                p_IsOpened = false;
            }

            if (controlChannelReceiver != null)
            {
                controlChannelReceiver.Close();
                Task.WaitAny(new Task[] { controlChannelReaderTask }, 1000);
            }

            if (controlConnection != null)
            {
                try
                {
                    controlConnection.Close();
                }
                catch (ObjectDisposedException)
                { }
                catch (InvalidOperationException)
                { }
            }

            if (controlChannelReceiver != null)
            {
                await controlChannelReaderTask;
            }
        }

        public FTPResponse NextResponse()
        {
            FTPResponse nextResponse = null;

            lock (controlChannelReceiver.Responses)
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

        public async Task<FTPAction> StartActionAsync(string Command)
        {
            if (!IsOpen)
            {
                throw new FTPClientException("Unable to issue a command on a closed client connection.");
            }

            if (Command.CompareTo(p_AbortTransferCommand) == 0)
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

            await OnCommandSent(p_CurrentAction.Command);

            await WriteCommandAsync(p_CurrentAction);

            return p_CurrentAction;
        }

        public async Task SetTransferMode()
        {
            FTPAction setmode = await RunCommandAsync(p_PassiveConnectionCommand).ContinueWith((t) =>
            {
                if (t.IsCompleted && t.Exception == null)
                {
                    t.Result.ExpectedAnswer = 227;
                    t.Result.CheckSuccess();
                    if (t.Result.Success)
                    {
                        foreach(EVAResponse r in EVAResponseFactory.GetResponses())
                        {
                            if (r.Code == t.Result.Response.Code)
                            {

                            }
                        }
                    }
                    return t.Result;
                }
                else
                {
                    if (t.IsCompleted && t.Exception is AggregateException)
                    {
                        throw t.Exception.InnerException;
                    }
                    throw t.Exception;
                }
            });
        }

        public async virtual Task<FTPAction> RunCommandAsync(string Command)
        {
            Task<FTPAction> commandTask = StartActionAsync(Command);
            FTPAction action = null;

            try
            {
                action = await commandTask;
            }
            catch (AggregateException e)
            {
                // unbox aggregated exceptions
                foreach (Exception ie in e.InnerExceptions)
                {
                    throw ie;
                }
            }

            return action;
        }

        private async Task WriteCommandAsync(FTPAction action)
        {
            try
            {
                await controlWriter.WriteLineAsync(action.Command);
            }
            catch (Exception e)
            {
                if (!IsOpen && (e is ObjectDisposedException))
                {
                    p_CurrentAction.AsyncTaskCompletionSource.SetException(new FTPClientException("The connection was closed by the server."));
                }
                else
                {
                    action.AsyncTaskCompletionSource.SetException(e);
                }
            }
        }

        protected async Task OnDataCommandCompleted()
        {
            p_OpenedDataConnection = false;
            //            OnControlCommandCompleted();
            await Task.CompletedTask;
        }

        protected async virtual Task OnCommandSent(string Line)
        {
            await Task.CompletedTask;

            EventHandler<CommandSentEventArgs> handler = CommandSent;
            if (handler != null)
            {
                try
                {
                    handler(this, new CommandSentEventArgs(Line));
                }
                catch
                {
                    // no exceptions from event handlers
                }
            }

            await Task.CompletedTask;
        }

        protected async virtual Task OnResponseReceived(ResponseReceivedEventArgs e)
        {
            await Task.CompletedTask;

            EventHandler<ResponseReceivedEventArgs> handler = ResponseReceived;
            if (handler != null)
            {
                try
                {
                    handler(this, e);
                }
                catch
                {
                    // no exceptions from event handlers
                }
            }

            await Task.CompletedTask;
        }

        protected async virtual Task OnActionCompleted(FTPAction Action)
        {
            await Task.CompletedTask;

            EventHandler<ActionCompletedEventArgs> handler = ActionCompleted;
            try
            {
                if (handler != null)
                {
                    handler(this, new ActionCompletedEventArgs(Action));
                }

                if (Action.AsyncTask.IsCompleted)
                {
                    return;
                }

                Action.AsyncTaskCompletionSource.SetResult(Action);
            }
            catch (Exception e)
            {
                if (!Action.AsyncTask.IsCompleted)
                {
                    Action.AsyncTaskCompletionSource.SetException(e);
                }
            }
        }

        private async Task<StreamWriter> OpenWriter(TcpClient connection)
        {
            StreamWriter writer = new StreamWriter(connection.GetStream(), Encoding.ASCII)
            {
                NewLine = "\r\n",
                AutoFlush = true
            };
            await Task.CompletedTask;
            return writer;
        }

        private async Task<StreamReader> OpenReader(TcpClient connection)
        {
            await Task.CompletedTask;
            return new StreamReader(connection.GetStream(), Encoding.ASCII);
        }

        private async Task AsyncControlReader(StreamReader reader, FTPControlChannelReceiver receiver)
        {
            do
            {
                bool empty = false;

                try
                {
                    string readLine = await reader.ReadLineAsync();
                    if (readLine != null)
                    {
                        empty = false;
                        await receiver.AddResponse(readLine);
                    }
                    else
                    {
                        empty = true;
                    }
                }
                catch (Exception e)
                {
                    receiver.SetException(e);
                    break;
                }

                if (empty) await Task.Delay(10);
            } while (!receiver.CloseNow);

            reader.Close();
        }

        private async Task OnControlCommandCompleted(FTPResponse Response)
        {
            FTPAction lastAction = null;

            lock (SyncRoot)
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
                await OnActionCompleted(lastAction);
            }
        }

        private async void OnControlChannelResponseReceived(Object sender, ResponseReceivedEventArgs e)
        {
            await OnResponseReceived(e);
        }

        private async void OnControlChannelResponseCompleted(Object sender, ResponseCompletedEventArgs e)
        {
            switch (e.Response.Code)
            {
                case 150:
                    lock (SyncRoot)
                    {
                        p_OpenedDataConnection = true;
                    }
                    return;

                case 220:
                    lock (SyncRoot)
                    {
                        p_IsOpened = true;
                    }
                    return;

                case 221:
                    lock (SyncRoot)
                    {
                        p_IsOpened = false;
                    }
                    break;

                case 421:
                    lock (SyncRoot)
                    {
                        p_IsOpened = false;
                        p_ForciblyClosed = true;
                        controlConnection.Close();
                    }
                    return;

                default:
                    break;
            }

            await OnControlCommandCompleted(e.Response);
        }
    }

    // EVA specific exception
    public class EVAClientException : FTPClientException
    {
        internal EVAClientException()
        {
        }

        internal EVAClientException(string message)
            : base(message)
        {
        }

        internal EVAClientException(string message, Exception inner) : base(message, inner)
        {
        }
    }

    // EVA specific FTP client class
    //
    // It uses strictly the TPL and tries to avoid blocking in most calls.
    // Use the provided events to get notified on commands sent, reponses received and commands completed.
    public class EVAClient : FTPClient
    {
        public new event EventHandler<ActionCompletedEventArgs> ActionCompleted;

        private bool p_IsLoggedIn = false;
        private bool p_IgnoreLoginError = false;
        private string p_User = EVAConstants.EVADefaultUser;
        private string p_Password = EVAConstants.EVADefaultPassword;

        private List<Task> outstandingEventHandlers = new List<Task>();
        private TFFSNameTable nameTable = TFFSNameTable.GetLatest();
        private EVACommands commands = EVACommandFactory.GetCommands();

        public EVAClient() :
            base(EVAConstants.EVADefaultIP)
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

        public string User
        {
            get
            {
                return p_User;
            }
            set
            {
                p_User = value;
            }
        }

        public string Password
        {
            get
            {
                return p_Password;
            }
            set
            {
                p_Password = value;
            }
        }

        public bool IsLoggedIn
        {
            get
            {
                return p_IsLoggedIn;
            }
        }

        public bool IgnoreLoginErrors
        {
            get
            {
                return p_IgnoreLoginError;
            }
            set
            {
                p_IgnoreLoginError = value;
            }
        }

        protected override object SyncRoot
        {
            get
            {
                return p_Lock;
            }
        }

        public override async Task OpenAsync()
        {
            await base.OpenAsync();
        }

        public override async Task OpenAsync(string Address)
        {
            await base.OpenAsync(Address);
        }

        public override async Task OpenAsync(string Address, int Port)
        {
            await base.OpenAsync(Address, Port);
        }

        public override async Task OpenAsync(IPAddress Address)
        {
            await base.OpenAsync(Address);
        }

        public override async Task OpenAsync(IPAddress Address, int Port)
        {
            await base.OpenAsync(Address, Port);
        }

        public async override Task CloseAsync()
        {
            await CompleteEventsAsync();

            if (IsLoggedIn)
            {
                await LogoutAsync();
            }

            await base.CloseAsync();

            await CompleteEventsAsync();
        }

        internal async Task CompleteEventsAsync(int Timeout = 1000)
        {
            if (RemoveFinishedEventHandlerTasks() == 0)
            {
                return;
            }

            Task[] waitForOutstandingHandlers = new Task[2];

            // wait the specified time for all outstanding event handlers to finish
            waitForOutstandingHandlers[0] = Task.Run(() => Task.WhenAll(outstandingEventHandlers));
            waitForOutstandingHandlers[1] = Task.Delay(Timeout);

            await Task.WhenAny(waitForOutstandingHandlers);
        }

        public async override Task<FTPAction> RunCommandAsync(string Command)
        {
            RemoveFinishedEventHandlerTasks();

            return await base.RunCommandAsync(Command);
        }

        public async Task<FTPAction> RunCommandAndCheckResultAsync(string Command, int Code)
        {
            return await RunCommandAsync(Command).ContinueWith((t) =>
            {
                if (t.IsCompleted && t.Exception == null)
                {
                    t.Result.ExpectedAnswer = Code;
                    t.Result.CheckSuccess();
                    return t.Result;
                }
                else
                {
                    if (t.IsCompleted && t.Exception is AggregateException)
                    {
                        throw t.Exception.InnerException;
                    }
                    throw t.Exception;
                }
            });
        }

        public async Task LoginAsync(string User, string Password)
        {
            p_User = User;
            p_Password = Password;
            await LoginAsync();
        }

        public async Task LoginAsync()
        {
            if (p_User.Length == 0 || p_Password.Length == 0)
            {
                throw new EVAClientException("Missing user name and/or password for login.");
            }

            FTPAction login = await RunCommandAndCheckResultAsync(String.Format(commands[EVACommandType.User].CommandValue, p_User), 331);

            if (login.Success)
            {
                FTPAction pw = await RunCommandAndCheckResultAsync(String.Format(commands[EVACommandType.Password].CommandValue, p_Password), 230);

                if (pw.Success)
                {
                    p_IsLoggedIn = true;
                    return;
                }
                else
                {
                    throw new EVAClientException(String.Format("Login failed: {0:s}", pw.Response.ToString()));
                }
            }
            else
            {
                throw new EVAClientException(String.Format("Login failed: {0:s}", login.Response.ToString()));
            }
        }

        public async Task LogoutAsync()
        {
            p_IsLoggedIn = false;
            if (IsConnected)
            {
                await RunCommandAndCheckResultAsync(commands[EVACommandType.Quit].CommandValue, 221);
            }
        }

        public async Task EnsureItIsEVAAsync()
        {
            FTPAction syst = await RunCommandAndCheckResultAsync(commands[EVACommandType.SystemType].CommandValue, 215);

            if (syst.Success)
            {
                if (!syst.Response.Message.StartsWith("AVM EVA"))
                {
                    throw new EVAClientException(String.Format("Unexpected system type: {0:s}", syst.Response.ToString()));
                }
            }
            else
            {
                throw new EVAClientException(String.Format("Unexpected error returned: {0:s}", syst.Response.ToString()));
            }
        }

        public async Task RebootAsync()
        {
            if (IsConnected)
            {
                await RunCommandAndCheckResultAsync(commands[EVACommandType.Reboot].CommandValue, 221);
            }
            else
            {
                throw new EVAClientException("The connection is not open.");
            }
        }

        public async Task<string> GetEnvironmentValueAsync(string Name)
        {
            return await GetEnvironmentValueAsync(Name, nameTable);
        }

        public async Task<string> GetEnvironmentValueAsync(string Name, TFFSNameTable NameTable)
        {
            CheckName(Name, NameTable);

            FTPAction getenv = await RunCommandAndCheckResultAsync(String.Format(commands[EVACommandType.GetEnvironmentValue].CommandValue, Name), 200);
            string output = null;

            if (getenv.Success)
            {
                ((MultiLineResponse)getenv.Response).Content.ForEach((e) =>
                {
                    if (e.Length >= Name.Length && e.StartsWith(Name))
                    {
                        output = output ?? e.Substring(Name.Length + 1).TrimStart();
                    }
                });
            }
            else
            {
                if (getenv.Response.Code == 501)
                {
                    if (getenv.Response.Message.CompareTo("environment variable not set") != 0)
                    {
                        throw new EVAClientException(String.Format("Unexpected error returned: {0:s}", getenv.Response.ToString()));
                    }
                }
                else
                {
                    throw new EVAClientException(String.Format("Unexpected error returned: {0:s}", getenv.Response.ToString()));
                }
            }

            return output;
        }

        public async Task RemoveEnvironmentValueAsync(string Name)
        {
            await RemoveEnvironmentValueAsync(Name, nameTable);
        }

        public async Task RemoveEnvironmentValueAsync(string Name, TFFSNameTable NameTable)
        {
            CheckName(Name, NameTable);

            FTPAction unsetenv = await RunCommandAndCheckResultAsync(String.Format(commands[EVACommandType.UnsetEnvironmentValue].CommandValue, Name), 200);

            if (!unsetenv.Success)
            {
                throw new EVAClientException(String.Format("Unexpected error returned: {0:s}", unsetenv.Response.ToString()));
            }
        }

        public async Task SetEnvironmentValueAsync(string Name, string Value)
        {
            await SetEnvironmentValueAsync(Name, Value, nameTable);
        }

        public async Task SetEnvironmentValueAsync(string Name, string Value, TFFSNameTable NameTable)
        {
            CheckName(Name, NameTable);

            FTPAction setenv = await RunCommandAndCheckResultAsync(String.Format(commands[EVACommandType.SetEnvironmentValue].CommandValue, Name, Value), 200);

            if (!setenv.Success)
            {
                throw new EVAClientException(String.Format("Unexpected error returned: {0:s}", setenv.Response.ToString()));
            }
        }

        public async Task SwitchSystemAsync()
        {
            string varName = nameTable.Entries[TFFSEnvironmentID.LinuxFSStart].Name;
            string value = await GetEnvironmentValueAsync(varName);

            value = value ?? "0";

            if (value.CompareTo("1") != 0 && value.CompareTo("0") != 0)
            {
                throw new EVAClientException(String.Format("Unexpected value '{0:s}' of '{1:s}' found.", value, varName));
            }

            string newValue = (value.CompareTo("0") == 0) ? "1" : "0";

            await SetEnvironmentValueAsync(varName, newValue);
        }

        public async Task<FTPAction> Store(MemoryStream data)
        {
            await Task.CompletedTask;
            return null;
        }

        public async Task<FTPAction> Store(string DataFile)
        {
            byte[] fileData = File.ReadAllBytes(DataFile);
            MemoryStream data = new MemoryStream(fileData);

            return await Store(data);
        }

        protected virtual void OnActionCompletedEVA(FTPAction Action)
        {
            EventHandler<ActionCompletedEventArgs> handler = ActionCompleted;
            if (handler != null)
            {
                try
                {
                    handler(this, new ActionCompletedEventArgs(Action));
                }
                catch
                {
                    // no exceptions from event handlers
                }
            }
        }

        private void Initialize()
        {
            base.ActionCompleted += OnActionCompleted;
        }

        private int RemoveFinishedEventHandlerTasks()
        {
            List<Task> finishedHandlers = new List<Task>();

            lock (SyncRoot)
            {
                outstandingEventHandlers.ForEach((task) => { if (task.IsCompleted) finishedHandlers.Add(task); });
                finishedHandlers.ForEach((task) => outstandingEventHandlers.Remove(task));
            }
            return outstandingEventHandlers.Count;
        }

        private void CheckName(string name, TFFSNameTable table)
        {
            if (table != null && table.FindID(name) == TFFSEnvironmentID.Free)
            {
                throw new EVAClientException(String.Format("Variable name not found in the specified name table ({0}).", table.Version));
            }
        }

        private void OnActionCompleted(Object sender, ActionCompletedEventArgs e)
        {
            switch (e.Action.Response.Code)
            {
                case 530:
                    if (p_IgnoreLoginError)
                    {
                        break;
                    }
                    if (e.Action.Command.StartsWith(commands[EVACommandType.Password].CommandValue))
                    {
                        e.Action.AsyncTaskCompletionSource.SetException(new EVAClientException("Login failed, wrong password."));
                    }
                    else
                    {
                        e.Action.AsyncTaskCompletionSource.SetException(new EVAClientException("Login needed."));
                    }
                    return;

                case 221:
                    lock(SyncRoot)
                    {
                        p_IsLoggedIn = false;
                    }
                    break;

                default:
                    break;
            }

            FTPAction clone = e.Action.Clone();

            lock (SyncRoot)
            {
                outstandingEventHandlers.Add(Task.Run(() => OnActionCompletedEVA(clone)));
            }
        }
    }
}

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

        // get the latest implemented name table
        public static TFFSNameTable GetLatest()
        {
            return TFFSNameTable.GetNameTable("@L");
        }
    }
}
'@;
}

Get-TypeData -TypeName YourFritz.EVA.Discovery