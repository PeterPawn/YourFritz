using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;

namespace YourFritz.EVA
{
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
        private IPAddress p_BoxIP = IPAddress.Parse(EVADefaults.EVADefaultIP);
        private IPAddress p_BroadcastAddress = IPAddress.Broadcast;
        private int p_DiscoveryPort = EVADefaults.EVADefaultDiscoveryPort;
        private bool p_IsRunning = false;
        private bool p_Canceled = false;
        private int p_Timeout = EVADefaults.EVADiscoveryTimeout;
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
            if (p_IsRunning)
            {
                throw new EVADiscoveryException("Discovery is already running.");
            }
            else
            {
                p_IsRunning = true;
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
                                        canceled = true;
                                    }
                                }
                            }
                            
                            if (ctSource.IsCancellationRequested)
                            {
                                canceled = true;
                            }
                        }
                    }
                }),

                // broadcast discovery packets, do not use cancellation token for the outer loop
                // the first packet is sent with a 10 ms delay, later the interval will grow up to 1000 ms
                Task.Factory.StartNew(async () =>
                {
                    IPEndPoint ep = new IPEndPoint(p_BroadcastAddress, p_DiscoveryPort);
                    byte[] data = new DiscoveryUdpPacket(sendAddress).ToBytes();
                    int delay = 10;

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

                            if (ctSource.IsCancellationRequested)
                            {
                                canceled = true;
                            }

                            sender.Send(data, data.Length, ep);

                            if (!canceled)
                            {
                                OnPacketSent(sendAddress, p_DiscoveryPort, data);
                                delay = 1000;
                            }
                        }

                        // send one more packet to terminate listening loop
                        sender.Send(data, data.Length, ep);
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

                    netIOTasks.Remove(finished);

                    if (finished is Task<Task> && !p_TimeoutElapsed)
                    {
                        netIOTasks.Add(((Task<Task>)finished).Result);
                    }
                    else
                    {
                        if (!ctSource.IsCancellationRequested && (p_TimeoutElapsed || (p_StopOnFirstFound && foundDevices.Count > 0)))
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
}
