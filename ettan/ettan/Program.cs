using iMobileDevice;
using iMobileDevice.iDevice;
using iMobileDevice.Lockdown;
using CSCore.SoundIn;
using System;
using System.Collections.ObjectModel;

namespace ettan
{
    class Program
    {
        static void Main(string[] args)
        {
            //Must load imobiledevice at beginning
            NativeLibraries.Load();
            int temp = 0;
            uint sent = 0;
            var idevice = LibiMobileDevice.Instance.iDevice;
            var lockdown = LibiMobileDevice.Instance.Lockdown;

            //Find iPhone
            idevice.idevice_get_device_list(out ReadOnlyCollection<string> udids, ref temp).ThrowOnError();
            idevice.idevice_new(out iDeviceHandle deviceHandle, udids[0]).ThrowOnError();

            //Start TCP Service
            lockdown.lockdownd_client_new_with_handshake(deviceHandle, out LockdownClientHandle lockdownHandle, "KK Comp").ThrowOnError();
            idevice.idevice_connect(deviceHandle, 8080, out iDeviceConnectionHandle connection);
            Console.WriteLine("Connected!");

            //Setup audio stream
            WasapiCapture capture = new WasapiLoopbackCapture();
            capture.Initialize();

            capture.DataAvailable += (sender, eArgs) =>
            {
                //For some reason ios plays at half speed, so get rid of half of the frames (1 frame = 4 bytes) in the stream
                var converted = new byte[eArgs.ByteCount / 2];
                for (int i = 0; i < eArgs.ByteCount; i += 8)
                {
                    for (int j = 0; j < 4; j++)
                    {
                        converted[(i / 2) + j] = eArgs.Data[i + j];
                    }
                }

                idevice.idevice_connection_send(connection, converted, (uint)converted.Length, ref sent).ThrowOnError();
            };
            capture.Start();

            Console.ReadKey();
            capture.Stop();
            lockdown.lockdownd_goodbye(lockdownHandle);
            capture.Dispose();
        }
    }
}