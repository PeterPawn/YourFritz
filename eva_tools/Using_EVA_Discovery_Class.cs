using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using YourFritz.EVA;
using YourFritz.TFFS;

namespace YourFritz
{
    class Program
    {

        static void Main(string[] args)
        {
            Task.Run(() => Program.RunAsync(args)).Wait();
        }

        static async Task RunAsync(string[] args)
        {
            EVADiscovery disco = new EVADiscovery()
            {
                StopOnFirstFound = true,
                DiscoveryTimeout = 15
            };

            disco.DeviceFound += DeviceFound;
            disco.Started += DiscoveryStarted;
            disco.Stopped += DiscoveryStopped;
            disco.PacketSent += DiscoveryBlip;
            disco.PacketReceived += DiscoveryReceived;

            Console.CancelKeyPress += async (c, ea) =>
            {
                await disco.CancelAsync();
                ea.Cancel = true;
            };

            EVADevices devices;
            IPAddress evaAddress;

            try
            {
                Task<EVADevices> dt = disco.StartAsync();

                devices = await dt;

                if (devices.Count == 0)
                {
                    await Task.Delay(10); // let Cancel handler finish its work, if needed

                    await Console.Error.WriteLineAsync(String.Format("EVADiscovery: No device was found in {0:d} seconds.", disco.DiscoveryTimeout));

                    return;
                }
                else
                {
                    foreach (EVADevice dev in devices.Values)
                    {
                        Console.Error.WriteLine(String.Format("EVADiscovery: EVA device found at {0:s}", dev.Address.ToString()));
                    }
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine(String.Format("Exception: {0}", e.ToString()));
                return;
            }

            evaAddress = devices.Values.First<EVADevice>().Address;

            Console.Error.WriteLine(String.Format("FTPClient: Starting a FTP session with {0:s}", evaAddress.ToString()));

            EVAClient eva = new EVAClient();

            eva.CommandSent += CommandSent;
            eva.ResponseReceived += ResponseReceived;
            eva.ActionCompleted += ActionCompleted;

            try
            {
                await eva.OpenAsync(evaAddress);
                await eva.LoginAsync();
                await eva.EnsureItIsEVAAsync();

                string HWRevision = await eva.GetEnvironmentValueAsync("HWRevision");

                eva.MediaType = EVAMediaType.RAM;
                MemoryStream data = await eva.RetrieveStreamAsync("env");

                if (data != null && data.Length > 0)
                {
                    await Console.Error.WriteLineAsync(String.Format(@"{0:d} bytes read, retrieved data follows:", data.Length));
                    await Console.Error.WriteLineAsync(@"-----------------------------------------");
                    using (StreamReader r = new StreamReader(data))
                    {
                        await Console.Error.WriteLineAsync(r.ReadToEnd());
                    }
                    await Console.Error.WriteLineAsync(@"-----------------------------------------");
                }

            }
            catch (FTPClientException e)
            {
                await Console.Error.WriteLineAsync(String.Format("FTPClientException: {0:s}", e.Message));
            }
            catch (Exception e)
            {
                await Console.Error.WriteLineAsync(String.Format("Unhandled exception: {0:s}", e.ToString()));
            }

            await eva.CloseAsync();
        }

        static void DeviceFound(Object sender, DiscoveryDeviceFoundEventArgs e)
        {
            Console.Error.WriteLine(String.Format("EVADiscovery: Device found at {0}:{1:d}", e.Device.Address.ToString(), e.Device.Port));
        }

        static void DiscoveryStarted(Object sender, DiscoveryStartEventArgs e)
        {
            if (e.Address.Equals(IPAddress.Any))
            {
                Console.Error.WriteLine(String.Format("EVADiscovery: Discovery started, IP address will not be changed ..."));
            }
            else
            {
                Console.Error.WriteLine(String.Format("EVADiscovery: Discovery started, IP address will be set to {0} ...", e.Address.ToString()));
            }
        }

        static void DiscoveryStopped(Object sender, DiscoveryStopEventArgs e)
        {
            if (e.Canceled)
            {
                Console.Error.WriteLine(String.Format("EVADiscovery: Discovery canceled."));
            }
            else
            {
                Console.Error.WriteLine(String.Format("EVADiscovery: Discovery finished."));
            }
        }

        static void DiscoveryBlip(Object sender, DiscoveryPacketSentEventArgs e)
        {
            Console.Error.WriteLine(String.Format("EVADiscovery: Sending discovery packet ..."));
        }

        static void DiscoveryReceived(Object sender, DiscoveryPacketReceivedEventArgs e)
        {
            Console.Error.WriteLine(String.Format("EVADiscovery: Received answer packet from {0:s}:{1:d} ...", e.EndPoint.Address.ToString(), e.EndPoint.Port));
        }

        static void CommandSent(Object sender, CommandSentEventArgs e)
        {
            Console.Error.WriteLine(String.Format("< {0:s}", e.Line));
        }

        static void ResponseReceived(Object sender, ResponseReceivedEventArgs e)
        {
            Console.Error.WriteLine(String.Format("> {0:s}", e.Line));
        }

        static void ActionCompleted(Object source, ActionCompletedEventArgs e)
        {
            //if (e.Action.AsyncTask.IsFaulted)
            //{
            //    Debug.WriteLine(String.Format("Action failed: {0:s} => {1:s}", e.Action.Command, e.Action.Response.ToString()));
            //}
            //else
            //{
            //    string cmd = e.Action.Command;
            //    string rsp = e.Action.Response.ToString();
            //    string msg = String.Format("Action completed: {0:s} => {1:s}", cmd, rsp);
            //    Debug.WriteLine(msg);
            //    if (!e.Action.Response.IsSingleLine)
            //    {
            //        ((MultiLineResponse)e.Action.Response).Content.ForEach(action: (line) => Debug.WriteLine(String.Format("{0:s}", line)));
            //    }
            //}
        }
    }
}
