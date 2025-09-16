/**
 * Device Control Server for Pixel/Android Device
 * This server provides an HTTP API to control your Android device via ADB
 *
 * Prerequisites:
 * 1. Install Node.js
 * 2. Install ADB (Android Debug Bridge)
 * 3. Enable Developer Options and USB Debugging on your Pixel
 * 4. Connect device via USB or WiFi
 *
 * To run:
 * node device_control_server.js
 */

const express = require('express');
const cors = require('cors');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// Configuration
const APP_PACKAGE = 'com.braggingrights.bragging_rights_app'; // Correct package name from device
const FLUTTER_PROJECT_PATH = 'C:\\Users\\smyth\\OneDrive\\Desktop\\Projects\\Bragging_Rights\\bragging_rights_app';
const FLUTTER_PATH = 'C:\\flutter\\bin\\flutter.bat'; // Full path to Flutter

// ADB Path configuration
const ADB_PATH = 'C:/Users/smyth/AppData/Local/Android/Sdk/platform-tools/adb.exe';

// Utility function to execute commands
function executeCommand(command) {
    // Replace 'adb' with full path if it's an adb command
    if (command.startsWith('adb ')) {
        command = command.replace('adb ', `"${ADB_PATH}" `);
    }

    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error: ${error.message}`);
                reject({ success: false, error: error.message, stderr });
            } else {
                console.log(`Output: ${stdout}`);
                resolve({ success: true, output: stdout, stderr });
            }
        });
    });
}

// Check if ADB is installed and device is connected
async function checkADBConnection() {
    try {
        const result = await executeCommand('adb devices');
        const devices = result.output.split('\n')
            .filter(line => line.includes('\tdevice'))
            .map(line => line.split('\t')[0]);

        return {
            connected: devices.length > 0,
            devices: devices
        };
    } catch (error) {
        return { connected: false, devices: [] };
    }
}

// Routes

// Serve the HTML file
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'device_control.html'));
});

// Execute ADB command
app.post('/adb', async (req, res) => {
    const { command } = req.body;

    if (!command) {
        return res.status(400).json({ success: false, error: 'No command provided' });
    }

    try {
        // Check connection first
        const connection = await checkADBConnection();
        if (!connection.connected) {
            return res.json({
                success: false,
                error: 'No device connected. Please connect your Pixel device and enable USB debugging.'
            });
        }

        // Execute the ADB command
        const result = await executeCommand(`adb ${command}`);
        res.json(result);
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// Device control endpoints
app.post('/device/wake', async (req, res) => {
    try {
        const result = await executeCommand('adb shell input keyevent KEYCODE_WAKEUP');
        res.json({ ...result, action: 'Device awakened' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

app.post('/device/sleep', async (req, res) => {
    try {
        const result = await executeCommand('adb shell input keyevent KEYCODE_SLEEP');
        res.json({ ...result, action: 'Device put to sleep' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

app.post('/device/restart', async (req, res) => {
    try {
        const result = await executeCommand('adb reboot');
        res.json({ ...result, action: 'Device restarting' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

app.get('/device/status', async (req, res) => {
    try {
        const connection = await checkADBConnection();
        const battery = await executeCommand('adb shell dumpsys battery | grep level');
        const screen = await executeCommand('adb shell dumpsys power | grep "Display Power"');

        res.json({
            success: true,
            connected: connection.connected,
            devices: connection.devices,
            battery: battery.output,
            screen: screen.output
        });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// App control endpoints
app.post('/app/launch', async (req, res) => {
    console.log('Launch app requested');
    try {
        // First check if app is installed
        const checkInstalled = await executeCommand(`adb shell pm list packages`);
        console.log('Checking for package:', APP_PACKAGE);

        if (!checkInstalled.output.includes(APP_PACKAGE)) {
            console.log('App not found in installed packages');
            return res.json({
                success: false,
                error: `App package ${APP_PACKAGE} not installed. Please use Flutter Run to build and install first.`,
                suggestion: 'Click the "Flutter Run" button to build and install the app',
                installedPackages: checkInstalled.output.split('\n').filter(p => p.includes('bragging'))
            });
        }

        // Try multiple launch methods
        console.log('Attempting to launch app with monkey command');
        try {
            const result = await executeCommand(`adb shell monkey -p ${APP_PACKAGE} -c android.intent.category.LAUNCHER 1`);
            console.log('Launch result:', result);
            res.json({ ...result, action: 'App launched on device' });
        } catch (monkeyError) {
            // Try am start as fallback
            console.log('Monkey failed, trying am start');
            const result = await executeCommand(`adb shell am start -n ${APP_PACKAGE}/.MainActivity`);
            res.json({ ...result, action: 'App launched on device' });
        }
    } catch (error) {
        console.error('Launch failed:', error);
        res.json({ success: false, error: error.message });
    }
});

app.post('/app/close', async (req, res) => {
    console.log('Close app requested for package:', APP_PACKAGE);
    try {
        const result = await executeCommand(`adb shell am force-stop ${APP_PACKAGE}`);
        console.log('App closed successfully');
        res.json({ ...result, action: 'App closed' });
    } catch (error) {
        console.error('Close failed:', error);
        res.json({ success: false, error: error.message });
    }
});

app.post('/app/restart', async (req, res) => {
    console.log('Restart app requested for package:', APP_PACKAGE);
    try {
        // First stop the app
        console.log('Stopping app...');
        await executeCommand(`adb shell am force-stop ${APP_PACKAGE}`);

        // Wait a moment
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Launch the app again
        console.log('Launching app...');
        const result = await executeCommand(`adb shell monkey -p ${APP_PACKAGE} -c android.intent.category.LAUNCHER 1`);
        console.log('App restarted successfully');
        res.json({ ...result, action: 'App restarted' });
    } catch (error) {
        console.error('Restart failed:', error);
        res.json({ success: false, error: error.message });
    }
});

app.post('/app/clear', async (req, res) => {
    try {
        const result = await executeCommand(`adb shell pm clear ${APP_PACKAGE}`);
        res.json({ ...result, action: 'App data cleared' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

app.post('/app/install', async (req, res) => {
    const apkPath = req.body.apkPath || path.join(FLUTTER_PROJECT_PATH, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');

    try {
        if (!fs.existsSync(apkPath)) {
            return res.json({ success: false, error: 'APK file not found. Please build the app first.' });
        }

        const result = await executeCommand(`adb install -r "${apkPath}"`);
        res.json({ ...result, action: 'App installed' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

app.post('/app/uninstall', async (req, res) => {
    try {
        const result = await executeCommand(`adb uninstall ${APP_PACKAGE}`);
        res.json({ ...result, action: 'App uninstalled' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// Flutter specific endpoints
app.get('/flutter-run', async (req, res) => {
    // Actually run Flutter instead of just showing instructions
    const { spawn } = require('child_process');

    res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive'
    });

    res.write(`
        <html>
        <head>
            <title>Flutter Run - Live Output</title>
            <style>
                body {
                    font-family: 'Courier New', monospace;
                    background: #1e293b;
                    color: #10b981;
                    padding: 20px;
                    white-space: pre-wrap;
                    line-height: 1.4;
                }
                .error { color: #ef4444; }
                .info { color: #3b82f6; }
                .success { color: #10b981; }
                h2 { color: #f1f5f9; }
                .command {
                    background: #334155;
                    padding: 10px;
                    border-radius: 5px;
                    margin: 10px 0;
                }
            </style>
        </head>
        <body>
            <h2>🚀 Flutter Debug Mode - Live Output</h2>
            <div class="command">Executing: cd ${FLUTTER_PROJECT_PATH} && ${FLUTTER_PATH} run</div>
            <pre id="output">
    `);

    // Change directory and run Flutter with full path
    const flutterCommand = `"${FLUTTER_PATH}" run`;
    const flutterProcess = spawn(flutterCommand, [], {
        cwd: FLUTTER_PROJECT_PATH,
        shell: true
    });

    flutterProcess.stdout.on('data', (data) => {
        const output = data.toString();
        res.write(`<span class="success">${output}</span>`);
    });

    flutterProcess.stderr.on('data', (data) => {
        const error = data.toString();
        res.write(`<span class="error">${error}</span>`);
    });

    flutterProcess.on('close', (code) => {
        res.write(`
            </pre>
            <div class="info">Process exited with code ${code}</div>
            <div class="command">To run again, refresh this page or go back and click the button again.</div>
        </body>
        </html>
        `);
        res.end();
    });

    flutterProcess.on('error', (err) => {
        res.write(`<span class="error">Failed to start Flutter: ${err.message}</span>`);
        res.write(`</pre></body></html>`);
        res.end();
    });
});

app.post('/flutter/run', async (req, res) => {
    const mode = req.body.mode || 'debug'; // debug, profile, or release
    const { spawn } = require('child_process');

    try {
        // First, check if Flutter is available
        const versionCheck = await executeCommand(`"${FLUTTER_PATH}" --version`);

        console.log(`Starting Flutter in ${mode} mode...`);

        // Use spawn for long-running Flutter process with full path
        const flutterCommand = `"${FLUTTER_PATH}" run --${mode}`;
        const flutterProcess = spawn(flutterCommand, [], {
            cwd: FLUTTER_PROJECT_PATH,
            shell: true,
            detached: false
        });

        let output = '';
        let errorOutput = '';

        flutterProcess.stdout.on('data', (data) => {
            const text = data.toString();
            output += text;
            console.log(text);
        });

        flutterProcess.stderr.on('data', (data) => {
            const text = data.toString();
            errorOutput += text;
            console.error(text);
        });

        // Don't wait for process to complete, just confirm it started
        setTimeout(() => {
            res.json({
                success: true,
                action: `Flutter started in ${mode} mode`,
                message: 'Flutter is running. Check the terminal or /flutter-run page for live output.',
                initialOutput: output.substring(0, 500)
            });
        }, 2000);

    } catch (error) {
        res.json({
            success: false,
            error: error.message,
            suggestion: 'Please ensure Flutter is installed and in your PATH'
        });
    }
});

app.post('/flutter/hot-reload', async (req, res) => {
    try {
        // Send 'r' to the running Flutter process
        const result = await executeCommand('adb shell input text "r"');
        res.json({ ...result, action: 'Hot reload triggered' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

app.post('/flutter/hot-restart', async (req, res) => {
    try {
        // Send 'R' to the running Flutter process
        const result = await executeCommand('adb shell input text "R"');
        res.json({ ...result, action: 'Hot restart triggered' });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// Screenshot endpoint
app.post('/device/screenshot', async (req, res) => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `screenshot_${timestamp}.png`;

    try {
        await executeCommand(`adb shell screencap -p /sdcard/${filename}`);
        await executeCommand(`adb pull /sdcard/${filename} ./${filename}`);
        await executeCommand(`adb shell rm /sdcard/${filename}`);

        res.json({
            success: true,
            action: 'Screenshot captured',
            filename: filename,
            path: path.join(__dirname, filename)
        });
    } catch (error) {
        res.json({ success: false, error: error.message });
    }
});

// Start server
app.listen(PORT, async () => {
    console.log(`\n🚀 Device Control Server running on http://localhost:${PORT}`);
    console.log('\n📱 Checking ADB connection...');

    const connection = await checkADBConnection();
    if (connection.connected) {
        console.log(`✅ Device connected: ${connection.devices.join(', ')}`);
    } else {
        console.log('❌ No device connected. Please connect your Pixel and enable USB debugging.');
        console.log('\nTo connect via USB:');
        console.log('1. Enable Developer Options on your Pixel');
        console.log('2. Enable USB Debugging');
        console.log('3. Connect via USB cable');
        console.log('4. Accept the debugging prompt on your device');
        console.log('\nTo connect via WiFi:');
        console.log('1. Connect device via USB first');
        console.log('2. Run: adb tcpip 5555');
        console.log('3. Find device IP in Settings > About > Status');
        console.log('4. Run: adb connect <device-ip>:5555');
    }

    console.log('\n📂 Flutter project path:', FLUTTER_PROJECT_PATH);
    console.log('\n🌐 Open http://localhost:5000 in your browser to control your device');
});

// Error handling
process.on('uncaughtException', (err) => {
    console.error('Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});