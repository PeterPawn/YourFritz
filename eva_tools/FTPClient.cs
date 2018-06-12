using System;

namespace YourFritz.EVA
{
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
        public string Line { get; }
        public DateTime SentAt { get; }

        internal CommandSentEventArgs(string Line)
        {
            this.Line = Line;
            this.SentAt = DateTime.Now;
        }
    }

    public class ResponseReceivedEventArgs : EventArgs
    {
        public string Line { get; }
        public DateTime ReceivedAt { get; }

        internal ResponseReceivedEventArgs(string Line)
        {
            this.Line = Line;
            this.ReceivedAt = DateTime.Now;
        }
    }

    public class ResponseCompletedEventArgs : EventArgs
    {
        public int Code { get; }
        public string Message { get; }
        public DateTime ReceivedAt { get; }

        internal ResponseCompletedEventArgs(int Code, string Message)
        {
            this.Code = Code;
            this.Message = Message;
            this.ReceivedAt = DateTime.Now;
        }
    }

    public class CommandCompletedEventArgs : EventArgs
    {
        public string Command { get; }
        public FTPResponse Response { get; }
        public DateTime ReceivedAt { get; }

        internal CommandCompletedEventArgs(string Command, FTPResponse Response)
        {
            this.Command = Command;
            this.Response = Response;
            this.ReceivedAt = DateTime.Now;
        }
    }

    public class FTPResponse
    {
        private int p_Code;
        private string p_FirstLine;
        private string p_LastLine;
        private System.Collections.Generic.List<string> p_Content;
        private volatile System.Threading.Tasks.TaskCompletionSource<FTPResponse> p_CompletedTask;
        private bool p_IsComplete;
        private bool p_IsMultiline;

        public FTPResponse()
        {
            this.p_Content = new System.Collections.Generic.List<string>();
            this.p_CompletedTask = new System.Threading.Tasks.TaskCompletionSource<FTPResponse>();
            this.p_Code = -1;
            this.p_FirstLine = System.String.Empty;
            this.p_LastLine = System.String.Empty;
            this.p_IsComplete = false;
            this.p_IsMultiline = false;
        }

        public bool IsComplete
        {
            get
            {
                return this.p_IsComplete;
            }
        }

        public bool IsMultilineResponse
        {
            get
            {
                return this.p_IsMultiline;
            }
        }

        public int Code
        {
            get
            {
                return this.p_Code;
            }
            set
            {
                this.p_Code = value;
            }
        }

        public string FirstLine
        {
            get
            {
                if (!this.IsMultilineResponse)
                {
                    throw new FTPClientException("This is a single-line response from server, the `'FirstLine`' property is unavailable.");
                }
                return this.p_FirstLine;
            }
        }

        public string LastLine
        {
            get
            {
                if (!this.IsMultilineResponse)
                {
                    throw new FTPClientException("This is a single-line response from server, the `'LastLine`' property is unavailable.");
                }
                return this.p_LastLine;
            }
        }

        public System.Collections.Generic.List<string> Content
        {
            get
            {
                if (!this.IsMultilineResponse)
                {
                    throw new FTPClientException("This is a single-line response from server, the `'Content`' property is unavailable.");
                }
                return this.p_Content;
            }
        }

        public System.Collections.Generic.List<string> MultilineMessage
        {
            get
            {
                if (!this.IsMultilineResponse)
                {
                    throw new FTPClientException("This is a single-line response from server, use the `'Message`' property to access its content.");
                }
                return this.p_Content;
            }
        }

        public string Message
        {
            get
            {
                if (this.IsMultilineResponse)
                {
                    throw new FTPClientException("This is a multi-line response from server, use the `'MultilineMessage`' property to access its content.");
                }
                return this.p_FirstLine; // it is stored in the same property as the last line from multi-line messages
            }
        }

        public System.Threading.Tasks.TaskCompletionSource<FTPResponse> Completed
        {
            get
            {
                return this.p_CompletedTask;
            }
        }


        public void SingleLineResponse(string Line, int Code)
        {
            this.p_FirstLine = Line;
            this.p_Code = Code;
            this.SetCompletion();
        }

        public void StartMultiLineResponse(string Line)
        {
            lock (((System.Collections.ICollection)this.p_Content).SyncRoot)
            {
                this.p_Content.Add(Line);
            }
        }

        public void AppendLine(string Line)
        {
            lock (((System.Collections.ICollection)this.p_Content).SyncRoot)
            {
                this.p_Content.Add(Line);
            }
        }

        public void Finish(string LastLine, int Code)
        {
            if (this.p_Code != -1 && this.p_Code != Code)
            {
                throw new FTPClientException(String.Format("Multi-line response was started with code {0} and finished with code {1} - a violation of RFC 959.", this.p_Code, Code));
            }

            this.p_LastLine = LastLine;

            if (this.p_Code == -1)
            {
                this.p_Code = Code;
            }

            this.p_IsComplete = true;

            this.SetCompletion();
        }

        protected void SetCompletion()
        {
            this.p_CompletedTask.SetResult(this);
        }
    }

    public class FTPControlChannelReceiver
    {
        private System.Text.RegularExpressions.Regex p_MatchResponse;
        private int p_StatusCode;
        private string p_Message;
        private volatile FTPResponse p_FTPResponse;

        public EventHandler<ResponseReceivedEventArgs> ResponseReceived;
        public EventHandler<ResponseCompletedEventArgs> ResponseCompleted;

        public FTPControlChannelReceiver()
        {
            this.p_MatchResponse = new System.Text.RegularExpressions.Regex(@"^(?<code>\d{3})(?<delimiter>[ \t-])(?<message>.*)$", System.Text.RegularExpressions.RegexOptions.Compiled);
            this.p_FTPResponse = new FTPResponse();
            this.p_StatusCode = -1;
            this.p_Message = System.String.Empty;
        }

        public System.Threading.Tasks.TaskCompletionSource<FTPResponse> CompletedTask
        {
            get
            {
                return this.p_FTPResponse.Completed;
            }
        }

        public int Code
        {
            get
            {
                return this.p_StatusCode;
            }
        }

        public string Message
        {
            get
            {
                return this.p_Message;
            }
        }

        public void Push(string Line)
        {
            System.Text.RegularExpressions.MatchCollection matches = this.p_MatchResponse.Matches(Line);

            this.OnResponseReceived(Line);

            if (matches.Count > 0)
            {
                int code = -1;
                bool startMultiline = false;
                string message = System.String.Empty;

                foreach (System.Text.RegularExpressions.Group match in matches[0].Groups)
                {
                    if (match.Name.CompareTo("code") == 0)
                    {
                        code = System.Convert.ToInt32(match.Value);
                    }
                    else if (match.Name.CompareTo("delimiter") == 0)
                    {
                        if (match.Value.CompareTo("-") == 0)
                        {
                            startMultiline = true;
                        }
                        else
                        {
                            startMultiline = false;
                        }
                    }
                    else if (match.Name.CompareTo("message") == 0)
                    {
                        message = match.Value;
                    }
                }

                if (code != -1 && startMultiline)
                {
                    if (this.p_FTPResponse != null)
                    {
                        throw new FTPClientException(String.Format("Multi-line start message with code {0:d} (see RFC 959) after previous response lines.", code));
                    }
                    this.p_FTPResponse.StartMultiLineResponse(Line);
                }
                else if (code != -1 && !startMultiline)
                {
                    this.p_FTPResponse.Finish(message, code);

                    this.p_Message = message;
                    this.p_StatusCode = code;

                    this.OnResponseCompleted(this.p_StatusCode, this.p_Message);
                }
            }
            else
            {
                this.p_FTPResponse.AppendLine(Line);
            }
        }

        public FTPResponse Response
        {
            get
            {
                return this.p_FTPResponse;
            }
        }

        public void Clear()
        {
            this.p_Message = System.String.Empty;
            this.p_StatusCode = -1;
            this.p_FTPResponse = new FTPResponse();
        }

        protected virtual void OnResponseReceived(string Line)
        {
            EventHandler<ResponseReceivedEventArgs> handler = this.ResponseReceived;
            if (handler != null) handler(this, new ResponseReceivedEventArgs(Line));
        }

        protected virtual void OnResponseCompleted(int Code, string Message)
        {
            EventHandler<ResponseCompletedEventArgs> handler = this.ResponseCompleted;
            if (handler != null) handler(this, new ResponseCompletedEventArgs(Code, Message));
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
        public event EventHandler<CommandCompletedEventArgs> CommandCompleted;

        // properties fields
        private System.Net.IPAddress p_Address;
        private int p_Port;
        private DataConnectionMode p_DataConnectionMode;
        private string p_PassiveConnectionCommand;
        private DataType p_DataType;
        private int p_DataPort;
        private bool p_IsOpened;
        private string p_RunningCommand;
        private bool p_OpenedDataConnection;

        // solely private values
        private System.Net.Sockets.TcpClient controlConnection;
        private System.IO.StreamWriter controlWriter;
        private System.IO.StreamReader controlReader;
        private FTPControlChannelReceiver controlChannelReceiver;

        public FTPClient()
        {
            this.Initialize(System.Net.IPAddress.Any, 21);
        }

        public FTPClient(string Address)
        {
            this.Initialize(System.Net.IPAddress.Parse(Address), 21);
        }

        public FTPClient(string Address, int Port)
        {
            this.Initialize(System.Net.IPAddress.Parse(Address), Port);
        }

        public FTPClient(System.Net.IPAddress Address)
        {
            this.Initialize(Address, 21);
        }

        public FTPClient(System.Net.IPAddress Address, int Port)
        {
            this.Initialize(Address, Port);
        }

        public System.Net.IPAddress Address
        {
            get
            {
                return this.p_Address;
            }
        }

        public int Port
        {
            get
            {
                return this.p_Port;
            }
        }

        public DataConnectionMode ConnectionMode
        {
            get
            {
                return this.p_DataConnectionMode;
            }
            set
            {
                if (value != DataConnectionMode.Passive)
                {
                    throw new FTPClientException("Only passive transfer mode is implemented yet.");
                }

                this.p_DataConnectionMode = value;
            }
        }

        public string PassiveConnectionCommand
        {
            get
            {
                return this.p_PassiveConnectionCommand;
            }
            set
            {
                if (value.CompareTo("P@SW") != 0 && value.CompareTo("PASV") != 0)
                {
                    throw new FTPClientException("Only commands `'PASV`' and `'P@SW`' are supported.");
                }
                this.p_PassiveConnectionCommand = value;
            }
        }

        public DataType TransferType
        {
            get
            {
                return this.p_DataType;
            }
            set
            {
                if (value != DataType.Binary)
                {
                    throw new FTPClientException("Only binary transfers are supported yet.");
                }
                this.p_DataType = value;
            }
        }

        public int DataPort
        {
            get
            {
                return this.p_DataPort;
            }
            set
            {
                if (this.p_IsOpened)
                {
                    throw new FTPClientException("Data port may only be set on a closed connection.");
                }
                this.p_DataPort = value;
            }
        }

        public bool IsOpen
        {
            get
            {
                return this.p_IsOpened;
            }
        }

        public bool IsConnected
        {
            get
            {
                if (this.p_IsOpened)
                {
                    return this.controlConnection.Connected;
                }
                return false;
            }
        }

        public bool HasOpenDataConnection
        {
            get
            {
                return this.p_OpenedDataConnection;
            }
        }

        public string RunningCommand
        {
            get
            {
                return this.p_RunningCommand;
            }
        }

        public FTPResponse Response
        {
            get
            {
                return this.controlChannelReceiver.Response;
            }
        }

        public void Open()
        {
            this.Open(this.p_Address, this.p_Port);
        }

        public void Open(string Address)
        {
            this.Open(System.Net.IPAddress.Parse(Address), this.p_Port);
        }

        public void Open(string Address, int Port)
        {
            this.Open(System.Net.IPAddress.Parse(Address), Port);
        }

        public void Open(System.Net.IPAddress Address)
        {
            this.Open(Address, this.p_Port);
        }

        public void Open(System.Net.IPAddress Address, int Port)
        {
            if (this.p_IsOpened)
            {
                throw new FTPClientException("The connection is already opened.");
            }
            this.p_Address = Address;
            this.p_Port = Port;

            try
            {
                this.controlConnection = new System.Net.Sockets.TcpClient(this.p_Address.ToString(), this.p_Port);
            }
            catch (System.Net.Sockets.SocketException e)
            {
                throw new FTPClientException("Error connecting to FTP server.", e);
            }
            this.controlWriter = this.OpenWriter(this.controlConnection);
            this.controlChannelReceiver = new FTPControlChannelReceiver();
            this.controlChannelReceiver.ResponseReceived += this.ControlChannelResponseReceived;
            this.controlChannelReceiver.ResponseCompleted += this.ControlChannelResponseCompleted;
            this.controlReader = this.OpenReader(this.controlConnection);
            this.AsyncControlReader(this.controlReader, this.controlChannelReceiver);
        }

        public virtual void Close()
        {
            if (this.controlReader != null)
            {
                //              this.controlReader.Close();
                this.controlReader.Dispose();
                this.controlReader = null;
            }

            if (this.controlWriter != null)
            {
                //              this.controlWriter.Close();
                this.controlWriter.Dispose();
                this.controlWriter = null;
            }

            if (this.controlChannelReceiver != null)
            {
                this.controlChannelReceiver.Clear();
                this.controlChannelReceiver = null;
            }

            if (this.controlConnection != null)
            {
                try
                {
                    this.controlConnection.GetStream().Dispose();
                    this.controlConnection.Close();
                    this.controlConnection.Dispose();
                }
                catch (System.InvalidOperationException)
                {
                }
                this.controlConnection = null;
            }
        }

        public FTPResponse GetResponse()
        {
            FTPResponse lastResponse = this.controlChannelReceiver.Response;

            this.controlChannelReceiver.Clear();

            return lastResponse;
        }

        public void StartCommand(string Command)
        {
            if (Command.CompareTo(EVACommandFactory.GetCommands()[EVACommandType.Abort].CommandValue) != 0 && this.p_RunningCommand != null)
            {
                throw new FTPClientException("There is already a command in progress.");
            }

            if (Command.CompareTo(EVACommandFactory.GetCommands()[EVACommandType.Abort].CommandValue) != 0)
            {
                // remove any garbage from previous command, if the new one is not an ABOR command
                this.controlChannelReceiver.Clear();
            }

            // start the new command
            this.p_RunningCommand = Command;
            this.controlWriter.WriteLine(Command);
            this.OnCommandSent(Command);
        }

        public async System.Threading.Tasks.Task<FTPResponse> SendCommand(string Command)
        {
            this.StartCommand(Command);
            return await this.controlChannelReceiver.CompletedTask.Task;
        }

        protected void DataCommandCompleted()
        {
            this.p_OpenedDataConnection = false;
            this.ControlCommandCompleted();
        }

        protected virtual void OnCommandSent(string Line)
        {
            EventHandler<CommandSentEventArgs> handler = this.CommandSent;
            if (handler != null) handler(this, new CommandSentEventArgs(Line));
        }

        protected virtual void OnResponseReceived(ResponseReceivedEventArgs e)
        {
            EventHandler<ResponseReceivedEventArgs> handler = this.ResponseReceived;
            if (handler != null) handler(this, e);
        }

        protected virtual void OnCommandCompleted(string Command, FTPResponse Response)
        {
            EventHandler<CommandCompletedEventArgs> handler = this.CommandCompleted;
            if (handler != null) handler(this, new CommandCompletedEventArgs(Command, Response));
        }

        private void Initialize(System.Net.IPAddress address, int port)
        {
            this.p_Address = address;
            this.p_Port = port;
            this.p_DataConnectionMode = DataConnectionMode.Passive;
            this.p_PassiveConnectionCommand = "P@SW";
            this.p_DataType = DataType.Binary;
            this.p_DataPort = 22;
            this.p_IsOpened = false;
        }

        private System.IO.StreamWriter OpenWriter(System.Net.Sockets.TcpClient connection)
        {
            System.IO.StreamWriter writer = new System.IO.StreamWriter(connection.GetStream(), System.Text.Encoding.ASCII);
            writer.NewLine = "\r\n";
            writer.AutoFlush = true;
            return writer;
        }

        private System.IO.StreamReader OpenReader(System.Net.Sockets.TcpClient connection)
        {
            System.IO.StreamReader reader = new System.IO.StreamReader(connection.GetStream(), System.Text.Encoding.ASCII);
            return reader;
        }

        private async void AsyncControlReader(System.IO.StreamReader reader, FTPControlChannelReceiver receiver)
        {
            do
            {
                string readLine = await reader.ReadLineAsync();
                receiver.Push(readLine);
            } while (this.controlConnection.Connected);
        }

        private void ControlCommandCompleted()
        {
            string lastCommand = this.p_RunningCommand;

            this.p_RunningCommand = null;

            if (lastCommand != null && this.controlChannelReceiver.Response != null && this.controlChannelReceiver.Response.IsComplete)
            {
                this.OnCommandCompleted(lastCommand, this.controlChannelReceiver.Response);
            }
        }

        private void ControlChannelResponseReceived(Object sender, ResponseReceivedEventArgs e)
        {
            this.OnResponseReceived(e);
        }

        private void ControlChannelResponseCompleted(Object sender, ResponseCompletedEventArgs e)
        {
            if (e.Code == 150)
            {
                this.p_OpenedDataConnection = true;
                return;
            }

            if (e.Code == 421)
            {
                // server has closed the connection or will do it soon
                this.p_IsOpened = false;
            }

            if (e.Code == 530)
            {
                throw new FTPClientException("Login needed.");
            }

            this.ControlCommandCompleted();
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

        private bool p_IsLoggedIn;

        public EVAClient() :
            base(EVAClient.EVADefaultIP)
        {

        }

        public EVAClient(string Address) :
            base(Address)
        {
        }

        public EVAClient(string Address, int Port) :
            base(Address, Port)
        {
        }

        public EVAClient(System.Net.IPAddress Address) :
            base(Address)
        {
        }

        public EVAClient(System.Net.IPAddress Address, int Port) :
            base(Address, Port)
        {
        }

        public bool IsLoggedIn
        {
            get
            {
                return this.p_IsLoggedIn;
            }
        }

        public override void Close()
        {
            if (this.IsLoggedIn)
            {
                this.Logout();
            }

            ((FTPClient)this).Close();
        }

        public async System.Threading.Tasks.Task<FTPResponse> RunCommand(string Command)
        {
            return await base.SendCommand(Command);
        }

        public void Login()
        {
            this.p_IsLoggedIn = true;
            return;
        }

        public void Logout()
        {
            this.p_IsLoggedIn = false;
            return;
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
            FTPResponse resp;

            eva.CommandSent += CommandSent;
            eva.ResponseReceived += ResponseReceived;
            eva.CommandCompleted += CommandCompleted;

            eva.Open("192.168.130.1");
            eva.Response.Completed.Task.Wait();
            resp = eva.GetResponse();

            try
            {
                resp = await eva.RunCommand("LIST");
            }
            catch (YourFritz.EVA.FTPClientException e)
            {
                Console.WriteLine(e.ToString());
            }
            catch (YourFritz.EVA.EVAClientException e)
            {
                Console.WriteLine(e.ToString());
            }
            catch (Exception e)
            {
                Console.WriteLine(e.ToString());
            }

            eva.Close();
        }

        static void CommandSent(Object sender, CommandSentEventArgs e)
        {
            Console.WriteLine("< {0:s}", e.Line);
        }

        static void ResponseReceived(Object sender, ResponseReceivedEventArgs e)
        {
            Console.WriteLine("> {0:s}", e.Line);
        }

        static void CommandCompleted(Object source, CommandCompletedEventArgs e)
        {
            Console.WriteLine("Command : {0:s}", e.Command);
            Console.WriteLine("Response: {0:d} {1:s}", e.Response.Code, e.Response.Message);
            if (e.Response.IsMultilineResponse)
            {
                e.Response.Content.ForEach(line => Console.WriteLine("        : {0:s}", line));
            }
        }
    }
}
