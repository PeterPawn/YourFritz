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

    public class FTPResponse
    {
        private int p_Code;
        private string p_FirstLine;
        private string p_LastLine;
        private System.Collections.ArrayList p_Content;

        public FTPResponse(string FirstLine, int Code)
        {
            this.Initialize();

            this.p_FirstLine = FirstLine;
            this.p_Code = Code;
        }

        public FTPResponse(string Line)
        {
            this.Initialize();

            lock (this.p_Content.SyncRoot)
            { 
                this.p_Content.Add(Line);
            }
        }

        public bool IsComplete
        {
            get
            {
                return (this.p_Code != -1);
            }
        }

        public bool IsMultilineResponse
        {
            get
            {
                return ((this.p_FirstLine.Length == 0) && (this.p_Content.Count == 0) && (this.p_Code != -1));
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

        public System.Collections.ArrayList Content
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

        public string[] MultilineMessage
        {
            get
            {
                if (!this.IsMultilineResponse)
                {
                    throw new FTPClientException("This is a single-line response from server, use the `'Message`' property to access its content.");
                }
                return (string[])this.p_Content.ToArray();
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
                return this.p_LastLine; // it is stored in the same property as the last line from multi-line messages
            }
        }

        public void Dispose()
        {
            this.p_Content.Clear();
            this.p_Content = null;
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
        }

        public void AppendLine(string Line)
        {
            lock (this.p_Content.SyncRoot)
            {
                this.p_Content.Add(Line);
            }
        }

        private void Initialize()
        {
            this.p_Code = -1;
            this.p_FirstLine = System.String.Empty;
            this.p_LastLine = System.String.Empty;
            this.p_Content = new System.Collections.ArrayList();
        }
    }

    public class FTPControlChannelReceiver
    {
        private System.Threading.ManualResetEvent p_QueueNotEmpty;
        private System.Collections.Queue p_Responses;
        private System.Text.RegularExpressions.Regex p_MatchResponse;
        private int p_StatusCode;
        private string p_Message;
        private FTPResponse p_FTPResponse;
        private System.Threading.ManualResetEvent p_ResponseComplete;

        public FTPControlChannelReceiver()
        {
            this.p_QueueNotEmpty = new System.Threading.ManualResetEvent(false);
            this.p_Responses = new System.Collections.Queue();
            this.p_MatchResponse = new System.Text.RegularExpressions.Regex(@"^(?<code>\d{3})(?<delimiter>[ \t-])(?<message>.*)$", System.Text.RegularExpressions.RegexOptions.Compiled);
            this.p_FTPResponse = null;
            this.p_ResponseComplete = new System.Threading.ManualResetEvent(false);
            this.p_StatusCode = -1;
            this.p_Message = System.String.Empty;
        }

        ~FTPControlChannelReceiver()
        {
            this.p_QueueNotEmpty.Close();
            this.p_QueueNotEmpty.Dispose();
            this.p_Responses.Clear();
            this.p_FTPResponse.Dispose();
            this.p_FTPResponse = null;
            this.p_ResponseComplete.Dispose();
            this.p_ResponseComplete = null;
        }

        public System.Threading.ManualResetEvent DataReady
        {
            get
            {
                return this.p_QueueNotEmpty;
            }
        }

        public System.Threading.ManualResetEvent ResponseComplete
        {
            get
            {
                return this.p_ResponseComplete;
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

            lock (this.p_Responses)
            { 
                this.p_Responses.Enqueue((object) Line);
                this.p_QueueNotEmpty.Set();
            }

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
                    this.p_FTPResponse = new FTPResponse(message, code);
                }
                else if (code != -1 && !startMultiline)
                {
                    if (this.p_FTPResponse != null)
                    {
                        this.p_FTPResponse.Finish(message, code);
                    }
                    else
                    {
                        this.p_FTPResponse = new FTPResponse(message, code);
                    }
                    this.p_Message = message;
                    this.p_StatusCode = code;
                    this.p_ResponseComplete.Set();
                }
            }
            else
            {
                if (this.p_FTPResponse != null)
                {
                    this.p_FTPResponse.AppendLine(Line);
                }
                else
                {
                    this.p_FTPResponse = new FTPResponse(Line);
                }
            }

            if (this.p_FTPResponse != null)
            {
                if (this.p_FTPResponse.IsComplete)
                {
                    this.p_ResponseComplete.Set();
                }
            }
        }

        public FTPResponse Response
        {
            get
            {
                if (this.p_FTPResponse != null)
                {
                    if (this.p_FTPResponse.IsComplete)
                    {
                        return this.p_FTPResponse;
                    }
                }
                throw new FTPClientException("The response is not available yet.");
            }
        }

        public void Clear()
        {
            this.p_QueueNotEmpty.Reset();
            this.p_ResponseComplete.Reset();
            this.p_Message = System.String.Empty;
            this.p_StatusCode = -1;

            if (this.p_FTPResponse != null)
            {
                this.p_FTPResponse.Dispose();
            }
            this.p_FTPResponse = null;
        }

        public bool WaitData(int Timeout)
        {
            return this.p_QueueNotEmpty.WaitOne(Timeout);
        }

        public bool Wait(int Timeout)
        {
            return this.p_ResponseComplete.WaitOne(Timeout);
        }
    }

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

        // properties fields
        private System.Net.IPAddress p_Address;
        private int p_Port;
        private DataConnectionMode p_DataConnectionMode;
        private string p_PassiveConnectionCommand;
        private DataType p_DataType;
        private int p_DataPort;
        private bool p_IsOpened;

        // solely private values
        private System.Net.IPEndPoint controlEP;
        private System.Net.Sockets.TcpClient controlConnection;
        private System.IO.StreamWriter controlWriter;
        private System.IO.StreamReader controlReader;
        private FTPControlChannelReceiver controlChannelReceiver;

        public FTPClient()
        {
            this.Initialize(System.Net.IPAddress.Parse("192.168.178.1"), 21);
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

            this.controlEP = new System.Net.IPEndPoint(this.p_Address, this.p_Port);
            this.controlConnection = new System.Net.Sockets.TcpClient(this.controlEP);
            this.controlWriter = this.OpenWriter(this.controlConnection);
            this.controlChannelReceiver = new FTPControlChannelReceiver();
            this.controlReader = this.OpenReader(this.controlConnection);
            this.AsyncControlReader(this.controlReader, this.controlChannelReceiver);
        }

        public void Close()
        {
            if (this.controlReader != null)
            { 
                this.controlReader.Close();
                this.controlReader.Dispose();
                this.controlReader = null;
            }

            if (this.controlWriter != null)
            {
                this.controlWriter.Close();
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

            this.controlEP = null;
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
            return writer;
        }

        private System.IO.StreamReader OpenReader(System.Net.Sockets.TcpClient connection)
        {
            System.IO.StreamReader reader = new System.IO.StreamReader(connection.GetStream(), System.Text.Encoding.ASCII);
            return reader;
        }

        private async void AsyncControlReader(System.IO.StreamReader reader, FTPControlChannelReceiver receiver)
        {
            string readLine = await reader.ReadLineAsync();
            receiver.Push(readLine);
        }
    }

    public class TestFTPClient
    {
        static void Main(string[] args)
        {
            FTPControlChannelReceiver recv = new FTPControlChannelReceiver();

            recv.Push("211- Extensions supported:");
            recv.Push(" UTF8");
            recv.Push(" MDTM");
            recv.Push(" SIZE");
            recv.Push(" AUTH TLS");
            recv.Push(" PBSZ");
            recv.Push(" PROT");
            recv.Push("211 end");
            Console.WriteLine("Code   : {0:d}", recv.Code);
            Console.WriteLine("Message: {0}", recv.Message);
            recv.Clear();
            recv.Push("200 command executed");
            Console.WriteLine("Code   : {0:d}", recv.Code);
            Console.WriteLine("Message: {0}", recv.Message);
        }
    }
}
