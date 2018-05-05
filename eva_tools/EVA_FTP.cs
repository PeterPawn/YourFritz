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

}
