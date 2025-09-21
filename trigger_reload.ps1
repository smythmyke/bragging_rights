$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class SendKeys {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
}
"@
[SendKeys]::keybd_event(0x52, 0, 0, 0)
[SendKeys]::keybd_event(0x52, 0, 2, 0)