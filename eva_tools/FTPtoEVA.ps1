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
using System.Net;
using System.Net.Sockets;
using System.Timers;

namespace YourFritz.EVA
{
    public class UdpPacket
    {
        public enum Direction
        {
            Request = 1,
            Answer = 2,
        }

        public System.Net.IPAddress Address { get; }
        public Direction PacketType { get; }

        internal UdpPacket()
        {
            this.PacketType = Direction.Request;
            this.Address = new System.Net.IPAddress(0);
        }

        internal UdpPacket(System.Net.IPAddress requestedIP)
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
                this.Address = new System.Net.IPAddress(address);
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
        public System.Net.IPAddress Address { get; }
        public int Port { get; }

        internal Device(IPEndPoint ep, UdpPacket answer)
        {
            if (answer.PacketType != UdpPacket.Direction.Answer)
            {
                throw new DiscoveryException("The specified UDP packet is not a discovery response.");
            }

            if (!answer.Address.Equals(ep.Address))
            {
                throw new DiscoveryException("The IP address in the received packet does not match the address of sender in packet data.");
            }

            this.Address = ep.Address;
            this.Port = ep.Port;
        }
    }

    public class StartEventArgs : EventArgs
    {
        public System.Net.IPAddress Address { get; }
        public int Port { get; }
        public DateTime StartedAt { get; }

        internal StartEventArgs(System.Net.IPAddress address, int port)
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
        public System.Net.IPAddress Address { get; }
        public int Port { get; }
        public DateTime SentAt { get; }
        public byte[] SentData { get; }

        internal PacketSentEventArgs(System.Net.IPAddress address, int port, byte[] data)
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

    public delegate void StartDiscoveryEventHandler(Object sender, StartEventArgs e);
    public delegate void StopDiscoveryEventHandler(Object sender, StopEventArgs e);
    public delegate void PacketSentEventHandler(Object sender, PacketSentEventArgs e);
    public delegate void PacketReceivedEventHandler(Object sender, PacketReceivedEventArgs e);
    public delegate void DeviceFoundEventHandler(Object sender, DeviceFoundEventArgs e);

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
        public System.Net.IPAddress BoxIP { get; set; }
        // default broadcast address to use - any other value requires access to SocketOptions
        public System.Net.IPAddress BroadcastAddress { get; set; }
        // the UDP port to sent to/receive from
        public int DiscoveryPort { get; set; }
        // the discovered devices
        public Dictionary<System.Net.IPAddress, Device> FoundDevices { get; }
        // discovery active flag
        public bool IsRunning { get; internal set; }

        // the UDP packet for discovery
        private UdpPacket sendData = new UdpPacket();
        // the listener receiving any response
        private UdpClient listener = null;
        // the client used to send UDP broadcast packets
        private UdpClient sender = null;
        // the timer used to send one packet per second
        private Timer sendTimer = null;
        // event to set, if we are waiting for discovery to get finished
        private System.Threading.ManualResetEvent stopEvent = null;
        // stop on first device found
        private bool stopOnFirstDeviceFound = false;

        // events raised by this class
        public event StartDiscoveryEventHandler Started;
        public event StopDiscoveryEventHandler Stopped;
        public event PacketSentEventHandler PacketSent;
        public event PacketReceivedEventHandler PacketReceived;
        public event DeviceFoundEventHandler DeviceFound;

        public Discovery()
        {
			this.BoxIP = new System.Net.IPAddress(new byte[] { 192, 168, 178, 1 });
			this.BroadcastAddress = new System.Net.IPAddress(new byte[] { 255, 255, 255, 255 });
			this.DiscoveryPort = 5035;
 			this.FoundDevices = new Dictionary<System.Net.IPAddress, Device>();
			this.sendData = new UdpPacket(this.BoxIP);
			this.IsRunning = false;
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

        public void Start(System.Net.IPAddress newIP)
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
                this.sendData = new UdpPacket(new System.Net.IPAddress(0));
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
            System.Net.IPAddress newIP;

            if (requestedIP != null && requestedIP.Length > 0)
            {
                newIP = System.Net.IPAddress.Parse(requestedIP);
            }
            else
            {
                newIP = new System.Net.IPAddress(0);
            }
            this.Start(newIP);
        }

        public void Start()
        {
            this.Start(this.BoxIP);
        }

        public void Restart(System.Net.IPAddress newIP)
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

        protected virtual void OnStartDiscovery(System.Net.IPAddress address, int port)
        {
            StartDiscoveryEventHandler handler = this.Started;
            if (handler != null)
            {
                handler(this, new StartEventArgs(address, port));
            }
        }

        protected virtual void OnStopDiscovery(int count)
        {
            StopDiscoveryEventHandler handler = this.Stopped;
            if (handler != null)
            {
                handler(this, new StopEventArgs(count));
            }
        }

        protected virtual void OnPacketSent(System.Net.IPAddress address, int port, byte[] data)
        {
            PacketSentEventHandler handler = this.PacketSent;
            if (handler != null)
            {
                handler(this, new PacketSentEventArgs(address, port, data));
            }
        }

        protected virtual void OnPacketReceived(IPEndPoint ep, byte[] data)
        {
            PacketReceivedEventHandler handler = this.PacketReceived;
            if (handler != null)
            {
                handler(this, new PacketReceivedEventArgs(ep, data));
            }
        }

        protected virtual void OnDeviceFound(Device newDevice)
        {
            DeviceFoundEventHandler handler = this.DeviceFound;
            if (handler != null)
            {
                handler(this, new DeviceFoundEventArgs(newDevice));
            }
            if (this.stopOnFirstDeviceFound)
            {
                this.Stop();
            }
        }

        private static void UdpListenerCallback(IAsyncResult asyncRes)
        {
            Discovery discovery = (Discovery)asyncRes.AsyncState;
            IPEndPoint ep = new IPEndPoint(System.Net.IPAddress.Any, discovery.DiscoveryPort);
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