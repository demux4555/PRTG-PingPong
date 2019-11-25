# PRTG-PingPong

PingPong standalone sensor for PRTG

## Introduction

A standalone ping sensor w/jitter for PRTG. Includes response time (latency), jitter, and packet loss.

To do this with the sensors bundled with PRTG, you need two separate sensors: [Ping](https://www.paessler.com/manuals/prtg/ping_sensor) and [Ping Jitter](https://www.paessler.com/manuals/prtg/ping_jitter_sensor). If you want latency and jitter in the same sensor, you need a total of *three* sensors to accomplish this using the [Sensor Factory Sensor](https://www.paessler.com/manuals/prtg/sensor_factory_sensor). Unfortunately, Paessler has [no plans](https://kb.paessler.com/en/topic/60679-ping-jitter-as-additional-channel-in-ping-sensor) of combining these two.

![Screenshot](https://i.imgur.com/4wN1mPQ.png)

### Installing:

1. Copy the executable to the `"\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML"`  directory.
2. Add a sensor to the device of choice, using the "EXE/Script Advanced" type.
3. Select the executable from the "EXE/Script" pulldown menu.
4. Select "Set placeholders as environment values" under Environment.

There is no need to put anything in the sensor "Parameters" field. It will work without any additional options.

**Note:** some anti-virus might block the executable from either running or accessing the network. Check your [AV logs](https://i.imgur.com/UG5mFNA.png) for troubleshooting. Please inspect the source code if you feel unsure about allowing the program to run. [VirusTotal](https://www.virustotal.com/gui/file/228450fea535f5f6ee049e808c4b681b21a51863f36b2c2f31030e574bdf1d97/detection) shows 10 false positives on the v3.0.0.3 executable.  


### Compiling your own executable:
If you don't trust the hosted exe, you can very easily compile it for yourself.
1. Download AutoIt3 and SciTE from [autoitscript.com](https://www.autoitscript.com/site/autoit/downloads/)
2. Download the source files, while keeping the directory structure intact.
3. Open the main .au3 source file in SciTE. Go to Tools|Build, and you're done. The compiled exe will be saved in the same directory as the main source file.

### Advanced options:

```
Usage: SENSOR-PingPong.exe [-h:<target_name>] [-m:<method>] [-f:<prefix>]
                           [-n:<count>] [-w:<timeout>] [-i:<interval>] [-g]
                           [-c] [-d]

Options:
    -h    Destination hostname or IPv4 number.
          Note: env var %prtg_host% will be used if argument is omitted.
    -m    (wmi | ms | dll | autoit) Method of ping. Default is dll (Windows
          IP Helper API).
    -f    Channel names prefixes.
    -n    Number of echo requests to send (default 10).
    -w    Timeout in milliseconds to wait for each reply (default 4000).
    -i    Interval in milliseconds. Specify 0 for fast ping (default 500).
    -g    Do not send the warmup ping.
    -c    Do not add XML prolog and PRTG root elements to output (only show
          the channels).
    -d    Debug mode.
```

Ping method:
* `-m:wmi` utilizes WMI Win32_PingStatus.
* `-m:ms` utilizes Microsoft Windows PING.EXE.
* `-m:dll` utilizes Windows IP Helper API (iphlpapi.dll).
* `-m:autuoit` utilizes Autoit Ping() function.

The reason for having different methods of ping is due to the certain firewalls / anti-virus suites blocking particular echo request cargo strings and string lengths. This allows easier troubleshooting and fixes to get around those issues.  

**Tip:** By using the `-h:hostname` argument you can ping a completely different host than the parent device. The `-h` argument will always precede any host declared in the environment variable `%prtg_host%` (set by PRTG when executing the sensor - more info [here](https://www.paessler.com/manuals/prtg/custom_sensors)).

#### Example:

![Example](https://i.imgur.com/xv4AowI.png)


Sensor Parameters: `-h:www.nytimes.com -m:ms -f:"NY Times" -n:20 -w:1000 -i:1000`

This will ping remote host www.nytimes.com 20 times, with 1 sec interval, using a 1 sec timeout, with "NY Times" as prefix for all the channel names. It will utilize Microsoft Windows PING.EXE.


#### Notes:


Keep the total number of ping requests, interval time, and timeout values within reasonable limits. If the host is unreachable you will have *N pings × timeout × interval* as the total execution time of the sensor. The resulting execution time needs to be lower than the timeout value of the sensor itself.

If all ping requests fail or time out, the sensor goes to Error state.

#### References:
* http://www.voiptroubleshooter.com/indepth/jittersources.html

#### Changelog:
* 1.0.0.0		2918.09.10		Initial version, utilizing PING.EXE and Autoit Ping()
* 2.0.0.0		2019.11.15		Added _WmiPing() method
* 3.0.0.0		2019.11.16		Added _DllPing() method
* 3.0.0.1		2019.11.18		Code cleanup
* 3.0.0.3		2019.11.21		Code cleanup, copied ECHO UDF to this program to reduce dependencies
* 3.0.0.4		2019.11.25		Minor _Ping() issue fixed
