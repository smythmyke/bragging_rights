Set objShell = CreateObject("WScript.Shell")
objShell.CurrentDirectory = "C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights"
objShell.Run "cmd /k node device_control_server.js", 1, False