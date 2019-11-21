#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=https://github.com/demux4555/PRTG-PingPong
#AutoIt3Wrapper_Res_Description=PingPong standalone sensor for PRTG
#AutoIt3Wrapper_Res_Fileversion=3.0.0.3
#AutoIt3Wrapper_Res_ProductName=PingPong
#AutoIt3Wrapper_Res_ProductVersion=3.0.0.3
#AutoIt3Wrapper_Res_LegalCopyright=demux4555 - gpl-3.0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

; #DESCRIPTION# =================================================================================================================
; Title .........: PingPong standalone sensor for PRTG
; Description ...: Standalone PRTG sensor that outputs ping stats: Latency, Minimum, Maximum, Packet Loss, Jitter.
; Requirements ..: Device setting "Set placeholders as environment values" must be enabled to to access %_prtg_host%.
; Installation ..: Copy compiled exe to ".\PRTG Network Monitor\Custom Sensors\EXEXML\"
; Author(s) .....: demux4555
; Changelog .....:	1.0.0.0		2918.09.10		Initial version, utilizing PING.EXE and Autoit Ping().
;					2.0.0.0		2019.11.15		Added _WmiPing().
;					3.0.0.0		2019.11.16		Added _DllPing().
;					3.0.0.1		2019.11.18		Code cleanup.
;					3.0.0.3		2019.11.21		Code cleanup, copied ECHO UDF to this program to reduce dependencies.
; Todo ..........: Look into some kind of IPv6 functionality for the ping functions that support it.
;                  PING.EXE interval support by perhaps using consecutive runs of the command (not very elegant, meh).
;                  Custom cargo strings.
; Web ...........: https://github.com/demux4555/PRTG-PingPong
; License .......: GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
; ===============================================================================================================================

#include <String.au3>
#include <StringConstants.au3>
#include ".\includes\CmdLine_v2.au3"
#include ".\includes\PRTG_XML_udf.au3"

Global Const $hScriptTimer = TimerInit()										; Initializes execution timer to show how long time it takes to complete the program
OnAutoItExitRegister("OnExit")											; This is executed on script exit, and processes syslog messages
Global $oErrorHandler = ObjEvent("AutoIt.Error", "__Error_Handler")				; this calls __Error_Handler() to produce a proper error message

#Region ### COMMAND LINE ARGUMENTS ###

	_CmdLine_Parse("-")													; We parse any command line arguments that begin with hyphen i.e. -H:192.168.1.1. Not case sensitive.

	; Command line arguments. Not case sensitive.
	Global $_D			= ArgCheck( CmdLine("D"), False, 1 )			; -D  			-  Debug mode
	Global $_HELP 		= ArgCheck( CmdLine("?"), False, 1 )			; -?			-  Show help
	Global $_H 			= ArgCheck( CmdLine("H"), "" )					; -H:ipaddress  -  Host IP or name
	Global $_M 			= ArgCheck( CmdLine("M"), "" )					; -M:pingmethod	-  Ping method: wmi, ms, dll, autoit
	Global $_F 			= ArgCheck( CmdLine("F"), "" )					; -F:prefix  	-  Channel names prefixes
	Global $_N 			= ArgCheck( CmdLine("N"), 10 )					; -N:n  		-  Number of echo requests to send.
	Global $_W 			= ArgCheck( CmdLine("W"), 4000 )				; -W:n  		-  Timeout in milliseconds to wait for each reply.
	Global $_I 			= ArgCheck( CmdLine("I"), 500 )					; -I:n  		-  Interval in milliseconds. Specify 0 for fast ping.
	Global $_G 			= ArgCheck( CmdLine("G"), False, 1 )			; -G  			-  Skip warmup ping with -G (we use a warmup ping by default)
	Global $_CHAONLY 	= ArgCheck( CmdLine("C"), False, 1 )			; -C  			-  Do not add XML prolog and PRTG root elements to output (only show the channels)

	; Some quick argument checks to ensure we have valid numerical values
	If (Abs(Number($_N)) < 1) Then $_N = 10
	If (Abs(Number($_W)) < 0) Then $_W = 4000
	If (Abs(Number($_I)) < 0) Then $_I = 500

	If $_HELP Then
		_PrintHelp()
		Exit
	EndIf


#EndRegion ### COMMAND LINE ARGUMENTS ###


#Region ### Global VARIABLES for CONFIGURATION ###

	; ---- PRTG ENVIRONMENT VARIABLES ----
	; Ref: https://www.paessler.com/manuals/prtg/custom_sensors
	Global Const $prtg_host 	= EnvGet("prtg_host")				; Env var %prtg_host%. The IP address/DNS name entry of the device the sensor is created on. "IPv4 Address/DNS Name" from device settings, enabled through PRTG Sensor Settings "Set placeholders as environment values". Allows easy setting of host IP without command line arguments.
	Global Const $prtg_sensorid	= _EnvGet("prtg_sensorid", "XXXX")	; Env var %prtg_sensorid%. The ID of the EXE/Script sensor, used for debugging and syslog messages.
	Global Const $prtg_name		= EnvGet("prtg_name")				; The name of the EXE/Script sensor, used for debugging and syslog messages.

	; ---- SET PING DESTINATION ----
	; Note: Argument -H overrides %prtg_host%
	; Note: _DllPing() uses TCPNameToIP() to convert hostname to IP number
	If StringIsSpace($_H) Then
		If StringIsSpace($prtg_host) Then
			ERROR("ERROR: no host specified with -h or %prtg_host%")
			_PrintHelp()
			Exit 99
		Else
			$_H = $prtg_host
		EndIf
	EndIf

	; ---- DEFAULT VALUES FOR THE PING FUNCTIONS ----
	; Here you might change/force default number of echoes to send, timeout in millisecons, and send buffer size. Use reasonable values.
	; The variable $MsPingTimeDef will unfortunately depend on the localization of the Windows system. Some examples found after a few minutes of googling: EN is "time", NL is "tijd", FR is "temps", NO is "tid", IT is "durata".
	Global $MsPingTimeDef 		= "time", $MsPingTimeMs = "ms"	; i.e. "time=3ms"	("Reply from 129.240.118.130: bytes=32 time=3ms TTL=55")
	Global $PingCount 			= $_N
	Global $PingTimeout 		= $_W
	Global $PingBufferSize 		= 32
	Global $PingIntervalTime 	= $_I
	Global $PINGWARMUP 			= ($_G == True) ? (False) : (True)	; if -G is used on command line, we disable warmup ping. Might implement feature to allow more than 1 warmup ping. Not needed tbh, usnure if I'll bother.
	; DEFAULT STARTING VALUES
	; Definitively no need to mess around with these.
	Global $PingTimeMin 		= 30000
	Global $PingTimeMax 		= 0
	Global $PingTimeAvg
	Global $PingTimeJitter 		= 0
	Global $PingTotalJitter 	= 0
	Global $PingJitter 			= 0
	Global $PingReceived 		= 0
	Global $PingPrevPingTime 	= 0
	Global $PingTotal 			= 0
	Global $PingLost 			= 0
	Global $PingPacketLoss		= 0
	Global $WmiPing_StatusMsg 	= Null
	Global $DllPing_StatusMsg 	= Null
	Global $MsPingCmd 					; the PING.EXE command line
	; ERROR / WARNING STATUS
	Global $ERROR_STATUS 		= False				; this is used for PRTX XML <Error>1</Error>
	Global $WARNING_STATUS 		= False				; this is used for warning status (not implemented yet, unsure if I want to, tbh)

	; ---- CHANNEL NAMES ----
	; for the PRTG sensor. These can be prefixed using the -F argument, i.e. for allowing multiple hosts in the same sensor (in a bat script). TODO: allow multiple hosts in the same instance.
	Global $ChLatency 			= "Latency"
	Global $ChMinimum 			= "Minimum"
	Global $ChMaximum 			= "Maximum"
	Global $ChPacketLoss 		= "Packet Loss"
	Global $ChJitter 			= "Jitter"
	Global $ChExecTime 			= "Sensor Execution Time"
	; CHANNEL NAMES PREFIXES
	If Not StringIsSpace($_F) Then
		$ChLatency 				= $_F & " " & $ChLatency
		$ChMinimum 				= $_F & " " & $ChMinimum
		$ChMaximum 				= $_F & " " & $ChMaximum
		$ChPacketLoss 			= $_F & " " & $ChPacketLoss
		$ChJitter 				= $_F & " " & $ChJitter
		$ChExecTime 			= $_F & " " & $ChExecTime
	EndIf

#EndRegion ### Global VARIABLES for CONFIGURATION ###


#Region ### EXECUTE PING ###

	; ---- SECLECT PING METHOD ----
	; Defaults to _DllPing()
	Global $MSPING = False, $WMIPING = False, $AUTOITPING = False, $DLLPING = False
	Select
		Case $_M == StringLower("ms") ; we use StringLower() to avoid issues with numeric var types or empty vars
			$MSPING = True
			_MsPing($_H, $PingTimeout, $PingCount, $PingIntervalTime, $PINGWARMUP)
		Case $_M == StringLower("wmi")
			$WMIPING = True
			_WmiPing($_H, $PingTimeout, $PingCount, $PingIntervalTime, $PINGWARMUP)
		Case $_M == StringLower("autoit")
			$AUTOITPING = True
			_Ping($_H, $PingTimeout, $PingCount, $PingIntervalTime, $PINGWARMUP)
		Case Else	; Case $_M == StringLower("dll")
			$DLLPING = True
			_DllPing($_H, $PingTimeout, $PingCount, $PingIntervalTime, $PINGWARMUP)
	EndSelect

#EndRegion ### EXECUTE PING ###


#Region ### CHANNEL OUTPUT ###

	_PrtgShowXML()

	If Not $ERROR_STATUS Then
		If $MSPING Then _PrtgComment(" " & $MsPingCmd & " ")
		_PrtgChannel($ChLatency, $PingTimeAvg, "", $PRTG_CS_LATENCY)
		_PrtgChannel($ChMinimum, $PingTimeMin, "", $PRTG_CS_LATENCY+$PRTG_CS_HIDE)
		_PrtgChannel($ChMaximum, $PingTimeMax, "", $PRTG_CS_LATENCY+$PRTG_CS_HIDE)
		_PrtgChannel($ChPacketLoss, $PingPacketLoss, "", $PRTG_CS_PERCENT)
		_PrtgChannel($ChJitter, $PingJitter, "", $PRTG_CS_LATENCY)
		_PrtgChannel($ChExecTime, TimerDiff($hScriptTimer)/1000, "sec", $PRTG_CS_EXECTIME)
		_PrtgPrintTag("Text", "Latency: " & Round($PingTimeAvg,1) & "ms (PL: " & Round($PingPacketLoss,0) & "%)")
	Else
		_PrtgPrintTag("Text", "Host unreachable")
	EndIf

	_PrtgComment(" Sent=[" & $PingCount & "]   Received=[" & $PingReceived & "]   Lost=[" & $PingLost & "]   Loss=[" & $PingPacketLoss & "]   " & _
				 "Min=[" & $PingTimeMin & "]   Max=[" & $PingTimeMax & "]   Avg=[" & $PingTimeAvg & "]   Jitter=[" & $PingJitter & "] ")

	_PrtgShowXML()

#EndRegion ### CHANNEL OUTPUT ###


#Region    #### EXIT ################################################################################################################################################################################
Exit ;     ##########################################################################################################################################################################################
#EndRegion ##########################################################################################################################################################################################


#Region ### WMI PING RELATED STUFF ###


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _WmiPing
	; Description ...: Ping remote host using WMI Win32_PingStatus.
	; Syntax ........: _WmiPing($_sAddress[, $_iTimeout = 1000[, $_iCount = 4[, $_iInterval = 1000[, $_WARMUP = False]]]])
	; Parameters ....: $_sAddress	- hostname or IP address (will be converted to IPv4 address)
	;                  $_iTimeout	- [optional] Timeout in milliseconds to wait for each reply. Default is 1000.
	;                  $_iCount		- [optional] Number of echo requests to send. Default is 4.
	;                  $_iInterval	- [optional] Sending interval between packets in milliseconds Default is 1000.
	;                  $_WARMUP		- [optional] Send warmup ping. Default is False.
	; Return values .: Failure - Sets @error to non-zero
	; Result vars ...: $PingTimeMin, $PingTimeMax, $PingTimeAvg, $PingJitter,
	;                  $PingCount, $PingReceived, $PingLost, $PingPacketLoss, $ERROR_STATUS
	; Author ........: demux4555
	; Link ..........:
	; Example .......: No
	; Reference......: https://docs.microsoft.com/en-us/previous-versions/windows/desktop/wmipicmp/win32-pingstatus
	; ===============================================================================================================================
	Func _WmiPing($_sAddress, $_iTimeout = 1000, $_iCount = 4, $_iInterval = 1000, $_WARMUP = False)
		If StringIsSpace($_sAddress) Then Return SetError(1, -1, Null)
		If StringIsSpace($_iTimeout)  Or ($_iTimeout<=0) Or ($_iTimeout==Default)  Then $_iCount = 1000
		If StringIsSpace($_iCount)    Or ($_iCount<=0)   Or ($_iCount==Default)    Then $_iCount = 4
		If StringIsSpace($_iInterval) Or ($_iInterval<0) Or ($_iInterval==Default) Then $_iInterval = 1000
		Local $_INTERVAL = ($_iInterval<=9) ? (False) : (True)	; we disable Sleep() if interval is less than 10ms. Ref: https://www.autoitscript.com/autoit3/docs/functions/Sleep.htm
		If StringIsSpace($_WARMUP) Or ($_WARMUP==Default) Or ($_WARMUP==0) Or ($_WARMUP==False) Then
			$_WARMUP = False
		Else
			$_WARMUP = True
		EndIf

		Local Const $_iBufferSize = $PingBufferSize, $_bNoFragmentation = False, $_iRecordRoute = 0, $_bResolveAddressNames = False, $_sSourceRoute = ""
		Local Const $_sMachineName = "."												; "." is the same as local computer or "127.0.0.1". Note: technically, this allows pinging from a different host than the local system we're running this proram on i.e. "192.168.1.50". Ref: https://docs.microsoft.com/en-us/windows/win32/wmisdk/describing-a-wmi-namespace-object-path
		Local $_objPing  = ObjGet("winmgmts://" & $_sMachineName & "/root/CIMV2")		; Ref: https://docs.microsoft.com/en-us/windows/win32/wmisdk/constructing-a-moniker-string
		Local $_strQuery =  "SELECT * FROM Win32_PingStatus WHERE" & _					; SWbemServices.ExecQuery method, ref: https://docs.microsoft.com/en-us/windows/win32/wmisdk/swbemservices-execquery
							" Address='" & $_sAddress & "'" & _							; Value of the address requested. The form of the value can be either the computer name ("wxyz1234"), IPv4 address ("192.168.177.124"), or IPv6 address ("2010:836B:4179::836B:4179").
							" AND Timeout=" & $_iTimeout & _							; Time-out value in milliseconds. If a response is not received in this time, no response is assumed. The default is 1000 milliseconds.
							" AND BufferSize=" & $_iBufferSize & _						; Buffer size sent with the ping command. The default value is 32.
							" AND NoFragmentation=" & $_bNoFragmentation & _			; If TRUE, "Do not Fragment" is marked on the packets sent. The default is FALSE, not fragmented.
							" AND RecordRoute=" & $_iRecordRoute & _					; How many hops should be recorded while the packet is in route. The default is 0 (zero).
							" AND ResolveAddressNames=" & $_bResolveAddressNames & _	; Command resolves address names of output address values. The default is FALSE, which indicates no resolution.
							" AND SourceRoute='" & $_sSourceRoute & "'"					; Comma-separated list of valid Source Routes. The default is "".
		DEBUG($_strQuery)
		Local $_objProperties, $_iStatusCode = Null, $_iResponseTime = Null, $_sOutput = "", $_iResponseTimeTotal = 0, $_iPingCnt = 0

		; WARMUP PING ?
		If $_WARMUP Then
			$_objProperties = $_objPing.ExecQuery($_strQuery, "WQL", 0x10+0x20)	; wbemFlagReturnImmediately (16 (0x10))  +  wbemFlagForwardOnly (32 (0x20))
			If IsObj($_objProperties) Then
				For $_objProperty In $_objProperties
					$_iResponseTime = $_objProperty.ResponseTime		; Time elapsed to handle the request.
					$_iStatusCode   = $_objProperty.StatusCode			; Ping command status code
				Next
			EndIf

			$WmiPing_StatusMsg = __GetStatusMsg($_iStatusCode)	; convert ping command status code to a human readable message
			If @extended==0 Then
				DEBUG("Warmup ping: " & $_iResponseTime & "ms")
				If $_INTERVAL Then Sleep($_iInterval)
			Else
				DEBUG("Warmup WmiPing() error: " & $WmiPing_StatusMsg)
			EndIf
		EndIf


		; PING HOST AND COLLECT STATS
		For $I = 1 To $_iCount
			$_objProperties = $_objPing.ExecQuery($_strQuery, "WQL", 0x10+0x20)	; wbemFlagReturnImmediately (16 (0x10))  +  wbemFlagForwardOnly (32 (0x20))
			$_iStatusCode = Null
			$_iResponseTime = Null
			If IsObj($_objProperties) Then
				For $_objProperty In $_objProperties
					$_iResponseTime = $_objProperty.ResponseTime		; Time elapsed to handle the request.
					$_iStatusCode   = $_objProperty.StatusCode			; Ping command status code
				Next

				$WmiPing_StatusMsg = __GetStatusMsg($_iStatusCode)
				If @extended==0 Then
					DEBUG($I & ": " & $_iResponseTime & "ms")
				Else
					DEBUG("Ping WmiPing() error: " & $WmiPing_StatusMsg)
					ContinueLoop
				EndIf

				$PingReceived += 1						; increase the counter for number of ping replies
				__CalcPingMinMax($_iResponseTime)		; stores Min and Max values
				__CalcPingJitter($_iResponseTime)		; calculates jitter
				$PingTotal += $_iResponseTime			; sum of all ping values

				; we skip Sleep() on the last ping
				If ($I<$_iCount) And $_INTERVAL Then Sleep($_iInterval)

			EndIf

		Next

		$WARNING_STATUS = __CalcPacketLoss($_iCount)
		$ERROR_STATUS   = __CalcPingValues($_iCount)
		If $ERROR_STATUS Then SetError(1)

	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; COM error function
	; Ref: https://docs.microsoft.com/en-us/windows/win32/wmisdk/swbemlasterror
	; ===============================================================================================================================
	Func __Error_Handler()
		Local $_windesription = StringStripWS($oErrorHandler.windescription,1+2+4)	; Sigh, there are some super-annoying CR and LF at the end of this string. Unsure about their order, and suspect there is one or two spaces inbetween as well. I don't give a shit anymore. Strip leading/trailing/double WS.
		ERROR("COM Error intercepted  [Line: " & $oErrorHandler.scriptline & "] [Desc: " & $oErrorHandler.description & "] [Win desc:" & $_windesription & "] [Err#: 0x" & Hex($oErrorHandler.number, 8) & "]" )
		If $_D Then
			ERROR(	"err.description:    " & $oErrorHandler.description & @CRLF & _
					"err.windescription: " & $_windesription & @CRLF & _
					"err.number:         " & "0x" & Hex($oErrorHandler.number, 8) & @CRLF & _
					"err.lastdllerror:   " & $oErrorHandler.lastdllerror & @CRLF & _
					"err.scriptline:     " & $oErrorHandler.scriptline & @CRLF & _
					"err.source:         " & $oErrorHandler.source & @CRLF & _
					"err.helpfile:       " & $oErrorHandler.helpfile & @CRLF & _
					"err.helpcontext:    " & $oErrorHandler.helpcontext  & @CRLF )
		EndIf
		Return SetError($oErrorHandler.number)
	EndFunc


#EndRegion ### WMI PING RELATED STUFF ###


#Region ### DLL PING RELATED STUFF ###


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _DllPing
	; Description ...: Ping remote host using Windows IP Helper API (iphlpapi.dll)
	; Syntax ........: _DllPing($_sAddress[, $_iTimeout = 1000[, $_iCount = 4[, $_iInterval = 1000[, $_WARMUP = False]]]])
	; Parameters ....: $_sAddress   - hostname or IP address (will be converted to IPv4 address)
	;                  $_iTimeout	- [optional] Timeout in milliseconds to wait for each reply. Default is 1000.
	;                  $_iCount		- [optional] Number of echo requests to send. Default is 4.
	;                  $_iInterval	- [optional] Sending interval between packets in milliseconds Default is 1000.
	;                  $_WARMUP		- [optional] Send warmup ping. Default is False.
	; Return values .: Failure - Sets @error to non-zero
	; Result vars ...: $PingTimeMin, $PingTimeMax, $PingTimeAvg, $PingJitter,
	;                  $PingCount, $PingReceived, $PingLost, $PingPacketLoss, $ERROR_STATUS
	; Author ........: demux4555
	; Link ..........:
	; Example .......: No
	; Reference......: https://docs.microsoft.com/en-us/windows/win32/api/icmpapi/nf-icmpapi-icmpsendecho
	;                  http://vbnet.mvps.org/index.html?code/internet/ping.htm
	;                  https://git.znil.net/AutoIt/pinz/src/branch/master/pinz.au3
	;                  ( https://www.autoitscript.com/forum/topic/129525-ping-help/?tab=comments#comment-936244 )
	; ===============================================================================================================================
	Func _DllPing($_sAddress, $_iTimeout = 1000, $_iCount = 4, $_iInterval = 1000, $_WARMUP = False) ; ECHO As ICMP_ECHO_REPLY
		If StringIsSpace($_sAddress) Then Return SetError(-1, -1, Null)
		If StringIsSpace($_iTimeout)	Or ($_iTimeout<=0) Or ($_iTimeout==Default)  Then $_iCount = 1000
		If StringIsSpace($_iCount)		Or ($_iCount<=0)   Or ($_iCount==Default)    Then $_iCount = 4
		If StringIsSpace($_iInterval)	Or ($_iInterval<0) Or ($_iInterval==Default) Then $_iInterval = 1000
		Local $_INTERVAL = ($_iInterval<=9) ? (False) : (True)	; we disable Sleep() if interval is less than 10ms. Ref: https://www.autoitscript.com/autoit3/docs/functions/Sleep.htm
		$_WARMUP = ( StringIsSpace($_WARMUP) Or ($_WARMUP==Default) Or ($_WARMUP==0) Or ($_WARMUP==False) ) ? (False) : (True)
		If $_WARMUP Then $_iCount += 1

		If @AutoItX64 Then	; 32-bit required
			ERROR(@ScriptName & " - Error: ICMP structures only designed for 32-Bit Version")
			Exit 20
		EndIf

		; resolve hostname to IPv4 IP number
		If Not StringRegExp($_sAddress, "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$") Then	; Ref: https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
			Local $_sAddressResolved = $_sAddress
			TCPStartup()
			If Not (@error==0) Then
				ERROR("TCPStartup() error: " & @error)	; Windows API WSAStartup return value
				Exit 21
			EndIf
			$_sAddressResolved = TCPNameToIP($_sAddress)
			Local $_error = @error, $_sError
			If Not ($_error==0) Then
				If ($_error==11001) Then $_sError = " [Host not found]"	; WSAHOST_NOT_FOUND 	Ref: https://docs.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2
				ERROR('ERROR: could not resolve host: "' & $_sAddress & '" [WSAGetLastError: ' & $_error & ']' & $_sError)
				Exit 22
			EndIf
			TCPShutdown()
			$_sAddress = $_sAddressResolved
		EndIf

		Local $_iStatusCode = 0, $_iResponseTime = Null
		Local Const $_hIPHLPAPIDLL = DllOpen("Iphlpapi.dll")
		Local $_hPort
		Local $_INADDR_NONE = -1


		Local Const $_ulAddress = __inet_addr($_sAddress)	; convert the IPv4 address into a long representation i.e. "1.1.1.1" >> "16843009"
		If (Not ($_ulAddress == $_INADDR_NONE)) Then

			; IP_OPTION_INFORMATION structure
			; The IP_OPTION_INFORMATION structure describes the options to be included in the header of an IP packet.
			; Ref: https://docs.microsoft.com/en-us/windows/win32/api/ipexport/ns-ipexport-ip_option_information
			Local Const $_IP_OPTION_INFORMATION = _	; The IP options in the IP header of the reply, in the form of an IP_OPTION_INFORMATION structure.
					"UBYTE Ttl;" & _				; The Time to Live field in an IPv4 packet header. This is the Hop Limit field in an IPv6 header.
					"UBYTE Tos;" & _				; The type of service field in an IPv4 header. This member is currently silently ignored.
					"UBYTE Flags;" & _				; The Flags field. In IPv4, this is the Flags field in the IPv4 header. In IPv6, this field is represented by options headers.
					"UBYTE OptionsSize;" & _		; The size, in bytes, of IP options data.
					"PTR OptionsData"				; A pointer to options data.
			; ICMP_ECHO_REPLY structure
			; The ICMP_ECHO_REPLY structure describes the data returned in response to an IPv4 echo request.
			; Ref: https://docs.microsoft.com/en-us/windows/win32/api/ipexport/ns-ipexport-icmp_echo_reply
			Local Const $_tagICMP_ECHO_REPLY = _		; The ICMP_ECHO_REPLY structure describes the data returned in response to an IPv4 echo request.
					"ULONG Address;" & _			; Address of the host formatted as a u_long. Ref: https://docs.microsoft.com/en-us/windows/win32/api/inaddr/ns-inaddr-in_addr
					"ULONG Status;" & _				; The status (StatusCode) of the echo request, in the form of an IP_STATUS code. The possible values for this member are defined in the Ipexport.h header file.
					"ULONG RoundTripTime;" & _		; The round trip time, in milliseconds.
					"USHORT DataSize;" & _			; The data size, in bytes, of the reply.
					"USHORT Reserved;" & _			; Reserved for system use.
					"PTR Data;" & _					; A pointer to the reply data.
					$_IP_OPTION_INFORMATION			; The IP options in the IP header of the reply, in the form of an IP_OPTION_INFORMATION structure.

			; PING HOST AND COLLECT STATS
			Local Const $_sCargo = "abcdefghijklmnopqrstuvwabcdefghi"
			Local $_tEchoReply	; ByRef struct var used for the DLL data
			For $I = 1 To $_iCount
				$_hPort = DllCall($_hIPHLPAPIDLL, "HWND", "IcmpCreateFile")	; The IcmpCreateFile function opens a handle on which IPv4 ICMP echo requests can be issued. Ref: https://docs.microsoft.com/en-us/windows/win32/api/icmpapi/nf-icmpapi-icmpcreatefile
				$_hPort = $_hPort[0]
				If $_hPort Then
					$_tEchoReply = DllStructCreate($_tagICMP_ECHO_REPLY & ";char[355]")	; $_tEchoReply is a ByRef var
					__DllPing_IcmpSendEcho(	$_hPort, _
											$_ulAddress, _
											$_sCargo, _
											StringLen($_sCargo), _
											0, _
											DllStructGetPtr($_tEchoReply), _
											DllStructGetSize($_tEchoReply), _
											$_iTimeout, _
											$_hIPHLPAPIDLL)
					$_iResponseTime = DllStructGetData($_tEchoReply, "RoundTripTime")
					$_iStatusCode   = DllStructGetData($_tEchoReply, "Status")
;~ 					DEBUG("Address: " & __inet_ntoa( DllStructGetData($_tEchoReply, "Address") ))
					$DllPing_StatusMsg = __GetStatusMsg($_iStatusCode)

					; WARMUP PING ?
					If $_WARMUP And ($I==1) Then
						If (@extended == 0) Then
							DEBUG("Warmup ping: " & $_iResponseTime & "ms")
							If $_INTERVAL Then Sleep($_iInterval)
						Else
							DEBUG("Warmup DllPing() error: " & $DllPing_StatusMsg)
						EndIf
						DllCall($_hIPHLPAPIDLL, "UINT", "IcmpCloseHandle", "hwnd", $_hPort)	; The IcmpCloseHandle function closes a handle opened by a call to the IcmpCreateFile or Icmp6CreateFile functions. Ref: https://docs.microsoft.com/en-us/windows/win32/api/icmpapi/nf-icmpapi-icmpclosehandle
						ContinueLoop
					EndIf

					$DllPing_StatusMsg = __GetStatusMsg($_iStatusCode)
					If @extended==0 Then
						DEBUG($I & ": " & $_iResponseTime & "ms")
					Else
						DEBUG("Ping WmiPing() error: " & $DllPing_StatusMsg)
						ContinueLoop
					EndIf

					If $_iStatusCode = 0 Then	; IP_SUCCESS

						$PingReceived += 1						; increase the counter for number of ping replies
						__CalcPingMinMax($_iResponseTime)		; stores Min and Max values
						__CalcPingJitter($_iResponseTime)		; calculates jitter
						$PingTotal += $_iResponseTime			; sum of all ping values

						; we skip Sleep() on the last ping
						If ($I<$_iCount) And $_INTERVAL Then Sleep($_iInterval)
					EndIf

					DllCall($_hIPHLPAPIDLL, "UINT", "IcmpCloseHandle", "HWND", $_hPort)	; The IcmpCloseHandle function closes a handle opened by a call to the IcmpCreateFile or Icmp6CreateFile functions. Ref: https://docs.microsoft.com/en-us/windows/win32/api/icmpapi/nf-icmpapi-icmpclosehandle

				EndIf

			Next

			If $_WARMUP Then $_iCount -= 1
			$WARNING_STATUS = __CalcPacketLoss($_iCount)
			$ERROR_STATUS   = __CalcPingValues($_iCount)

		EndIf
		DllClose($_hIPHLPAPIDLL)
		If $ERROR_STATUS Then SetError(1)

	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; The IcmpSendEcho function sends an IPv4 ICMP echo request and returns any echo response replies. The call returns when the
	; time-out has expired or the reply buffer is filled.
	; Ref: https://docs.microsoft.com/en-us/windows/win32/api/icmpapi/nf-icmpapi-icmpsendecho
	; ===============================================================================================================================
	Func __DllPing_IcmpSendEcho($_IcmpHandle, $_DestinationAddress, $_RequestData, $_RequestSize, $_RequestOptions , $_ReplyBuffer, $_ReplySize, $_Timeout, $_ICMPDLL = "Iphlpapi.dll")
		Local $_aRet = DllCall($_ICMPDLL,   "DWORD", "IcmpSendEcho", _
											"HWND",  $_IcmpHandle, _			; The open handle returned by the IcmpCreateFile function.
											"UINT",  $_DestinationAddress, _	; The IPv4 destination address of the echo request, in the form of an IPAddr structure.
											"STR",   $_RequestData, _			; A pointer to a buffer that contains data to send in the request.
											"DWORD", $_RequestSize, _			; The size, in bytes, of the request data buffer pointed to by the RequestData parameter.
											"PTR",   $_RequestOptions , _		; A pointer to the IP header options for the request, in the form of an IP_OPTION_INFORMATION structure.
											"PTR",   $_ReplyBuffer, _			; A buffer to hold any replies to the echo request. Upon return, the buffer contains an array of ICMP_ECHO_REPLY structures followed by the options and data for the replies. The buffer should be large enough to hold at least one ICMP_ECHO_REPLY structure plus RequestSize bytes of data.
											"DWORD", $_ReplySize, _				; The allocated size, in bytes, of the reply buffer. The buffer should be large enough to hold at least one ICMP_ECHO_REPLY structure plus RequestSize bytes of data. This buffer should also be large enough to also hold 8 more bytes of data (the size of an ICMP error message).
											"DWORD", $_Timeout)					; The time, in milliseconds, to wait for replies.
		If @error Then Return SetError(@error + 1000, 0, 0)
		Return $_aRet[0]
	EndFunc


#EndRegion ### DLLPING RELATED STUFF ###


#Region ### PING.EXE RELATED STUFF ###


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _MsPing
	; Description ...: Ping remote host using Windows PING.EXE command
	; Syntax ........: _MsPing($_sHost[, $_iTimeout = 4000[, $_iCount = 4[, $_iInterval = Null[, $_WARMUP = False[, $_IPv = 4]]]]])
	; Parameters ....: $_sAddress   - hostname or IP address (will be converted to IPv4 address)
	;                  $_iTimeout	- [optional] Timeout in milliseconds to wait for each reply. Default is 1000.
	;                  $_iCount		- [optional] Number of echo requests to send. Default is 4.
	;                  $_iInterval	- [optional] NOT USED, for design compatibility with the other functions.
	;                  $_WARMUP		- [optional] Send warmup ping. Default is False.
	;                  $_IPv		- [optional] Force IPv4 or IPv6. Default is 4 (IPv4).
	; Return values .: Failure - Sets @error to non-zero
	; Result vars ...: $PingTimeMin, $PingTimeMax, $PingTimeAvg, $PingJitter,
	;                  $PingCount, $PingReceived, $PingLost, $PingPacketLoss, $ERROR_STATUS
	; Author ........: demux4555
	; Link ..........:
	; Example .......: No
	; Reference......: https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/ping
	;                : https://ss64.com/nt/ping.html
	; ===============================================================================================================================
	Func _MsPing($_sHost, $_iTimeout = 4000, $_iCount = 4, $_iInterval = Null, $_WARMUP = False, $_IPv = 4)
		If StringIsSpace($_sHost) Then Return SetError(-1, -1, Null)
		If StringIsSpace($_iTimeout)	Or ($_iTimeout<=0) Or ($_iTimeout==Default)  Then $_iCount = 1000
		If StringIsSpace($_iCount)		Or ($_iCount<=0)   Or ($_iCount==Default)    Then $_iCount = 4
		$_WARMUP = ( StringIsSpace($_WARMUP) Or ($_WARMUP==Default) Or ($_WARMUP==0) Or ($_WARMUP==False) ) ? (False) : (True)

		Local  Const $MsPingExe = @SystemDir & "\PING.EXE"		; full path and name of PING.EXE
		If $MSPING And (Not $WMIPING) Then
			If Not FileExists($MsPingExe) Then
				ERROR('ERROR: could not locate "' & $MsPingExe & '"')
				Exit 10
			EndIf
		EndIf

		; determining IPv4 or IPv6
		Switch Number($_IPv)
			Case 4
				$_IPv = " -4"
			Case 6
				$_IPv = " -6"
			Case Else
				$_IPv = " "
		EndSwitch

		Local $X = 0	; the eXtra number of warmup pings
		If $_WARMUP Then $X = 1

		; setting up entire command i.e. "C:\WINDOWS\system32\PING.EXE -4 -n 20 -l 32 -w 1500 vg.no"
		; Note: this is a Global variable (for debug purposes)
		$MsPingCmd = 	$MsPingExe & _
						$_IPv & _
						" -n " & $_iCount+$X & _
						" -l " & $PingBufferSize & _
						" -w " & $_iTimeout & " " & _
						$_sHost

		DEBUG($MsPingCmd)

		; PING HOST AND COLLECT STATS
		Local $_PID = Run($MsPingCmd, @SystemDir, @SW_HIDE, 0x8 )	; $STDERR_MERGED (0x8)
		If Not (@error==0) Then
			ERROR("ERROR: _MsPing() could not execute command: " & $MsPingCmd)
			Exit 11
		Else
;~ 			ProcessWaitClose($_PID)
			While ProcessExists($_PID)	; we use this instead of ProcessWaitClose() to reduce time with a couple of hundred ms because ProcessWaitClose() only polls every 250ms
				Sleep(10)
			WEnd
		EndIf

		Local $_sStdout = StdoutRead($_PID)
		If (@extended==0) Then				; @extended contains the number of bytes read
			ERROR("ERROR: _MsPing() no bytes read from command: " & $MsPingCmd)
			Exit 12
		EndIf

		Local $_aStdout = StringSplit($_sStdout, @CRLF, $STR_ENTIRESPLIT)
		If Not IsArray($_aStdout) Or Not (@error==0) Then
			ERROR("ERROR: _MsPing() could not parse output.")
			Exit 13
		EndIf

	;~ 	DEBUG($_sStdout)
	;~ 	_ArrayDisplay($_aStdout)

		Local $_sLine, $_iResponseTime
		For $N = 1 To $_aStdout[0]		; enumerate the lines in the PING.EXE output

			$_sLine = StringStripWS($_aStdout[$N], $STR_STRIPLEADING+$STR_STRIPTRAILING+$STR_STRIPSPACES)
			If StringIsSpace($_sLine) Then ContinueLoop

			If StringLeft($_sLine, 15) == "Ping statistics" Then ExitLoop		; looking for the last relevant output line i.e. "Ping statistics for 192.168.1.19:"
			If StringLeft($_sLine, 8) == "Pinging " Then		; This establishes the first line of ping replies by looking for "Pinging 192.168.1.19 with 32 bytes of data:"  or  "Pinging joi-wlan.local.lan [192.168.1.19] with 32 bytes of data:"

				; WARMUP PING ?
				If $_WARMUP Then		; If we use a warmup ping, we skip ahead and simply jump over the next line of output (which will be the very first ping reply, even if it timeouts or has an error message)
					$N += 1
					$_sLine = $_aStdout[$N]
					If Not __HASTIME($_sLine) Then
						DEBUG("Warmup _MsPing() error: " & $_sLine)
					Else
						DEBUG("Warmup ping: " & __GetMsPingTime($_sLine) & "ms")
					EndIf
				EndIf

				ContinueLoop

			EndIf

			If __HASTIME($_sLine) Then																; if we find "time=XXXms" or "time<1ms"

				$_iResponseTime = __GetMsPingTime($_sLine)
				If Not (@error==0) Then ContinueLoop

				DEBUG($PingReceived+1 & ": " & $_iResponseTime & "ms")

				$PingReceived += 1					; increase the counter for number of ping replies
				__CalcPingMinMax($_iResponseTime)	; stores Min and Max values
				__CalcPingJitter($_iResponseTime)	; calculates jitter
				$PingTotal += $_iResponseTime		; sum of all ping values

			Else

				DEBUG("_MsPing() error: " & $_sLine)
				ContinueLoop

			EndIf

		Next

		$WARNING_STATUS = __CalcPacketLoss($_iCount)
		$ERROR_STATUS   = __CalcPingValues($_iCount)
		If $ERROR_STATUS Then SetError(1)

	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; See if we find "time____ms" in PING.EXE output
	; RegExp: ".*?time.(.*?ms)" -- this also works with "time<1ms"
	; Note: searching for string "TTL=" only works with IPv4, so we don't use this method.
	; ===============================================================================================================================
	Func __HASTIME($_str)
		If StringRegExp($_str, ".*?"&$MsPingTimeDef&".(.*?"&$MsPingTimeMs&")") = 1 Then Return True
		Return False
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Extracts and returns the millisecond value from a line of PING.EXE output
	; Note: time<1 is returned as 0
	; ===============================================================================================================================
	Func __GetMsPingTime($_str)

		Local $_iLatency
		Local Const $_sTimeEqu = $MsPingTimeDef & "=" 					; i.e. "time="
		Local Const $_sLss1ms  = $MsPingTimeDef & "<1" & $MsPingTimeMs	; i.e. "time<1ms"

		If (StringInStr($_str, $_sLss1ms, 1) <> 0) Then											; if ping is less then 0 we simply set it to 0 (i.e. "time<1ms")
			$_iLatency = 0
		Else
			Local $_aBtwn = _StringBetween($_str, $_sTimeEqu, $MsPingTimeMs, 0, True)			; extract number between "time=" and "ms"
			If Not (@error==0) Then Return SetError(1, 0, "")
			$_str = $_aBtwn[0]

			If Not StringIsDigit($_str) Then Return SetError(3, 0, "")
			$_iLatency = Number($_str)
		EndIf

		If ($_iLatency >= 0) Then Return $_iLatency

		Return SetError(4, 0, "")	; if we managed to get here, something went wrong

	EndFunc


#EndRegion ### PING.EXE RELATED STUFF ###


#Region ### AutoIt Ping() RELATED STUFF ###


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _Ping
	; Description ...: Ping remote host using the Autoit Ping() function
	; Syntax ........: _Ping($_sHost[, $_iTimeout = 4000[, $_iCount = 4[, $_iInterval = 1000[, $_WARMUP = False]]]])
	; Parameters ....: $_sAddress   - hostname or IP address (will be converted to IPv4 address)
	;                  $_iTimeout	- [optional] Timeout in milliseconds to wait for each reply. Default is 1000.
	;                  $_iCount		- [optional] Number of echo requests to send. Default is 4.
	;                  $_iInterval	- [optional] NOT USED, for design compatibility with the other functions.
	;                  $_WARMUP		- [optional] Send warmup ping. Default is False.
	; Return values .: Failure - Sets @error to non-zero
	; Result vars ...: $PingTimeMin, $PingTimeMax, $PingTimeAvg, $PingJitter,
	;                  $PingCount, $PingReceived, $PingLost, $PingPacketLoss, $ERROR_STATUS
	; Author ........: demux4555
	; Link ..........:
	; Example .......: No
	; Reference......: https://www.autoitscript.com/autoit3/docs/functions/Ping.htm
	; ===============================================================================================================================
	Func _Ping($_sHost, $_iTimeout = 4000, $_iCount = 4, $_iInterval = 1000, $_WARMUP = False)
		If StringIsSpace($_sHost) Then Return SetError(-1, -1, Null)
		If StringIsSpace($_iTimeout)	Or ($_iTimeout<=0) Or ($_iTimeout==Default)  Then $_iCount = 1000
		If StringIsSpace($_iCount)		Or ($_iCount<=0)   Or ($_iCount==Default)    Then $_iCount = 4
		If StringIsSpace($_iInterval)	Or ($_iInterval<0) Or ($_iInterval==Default) Then $_iInterval = 1000
		Local $_INTERVAL = ($_iInterval<=9) ? (False) : (True)	; we disable Sleep() if interval is less than 10ms. Ref: https://www.autoitscript.com/autoit3/docs/functions/Sleep.htm
		$_WARMUP = ( StringIsSpace($_WARMUP) Or ($_WARMUP==Default) Or ($_WARMUP==0) Or ($_WARMUP==False) ) ? (False) : (True)

		Local $_iResponseTime, $_error

		; WARMUP PING ?
		If $_WARMUP Then
			$_iResponseTime = Ping($_H, $_iTimeout)
			$_error = @error	; 1 = Host is offline, 2 = Host is unreachable (timeout), 3 = Bad destination, 4 = Other errors
			If (Not ($_error==0)) Or ($_iResponseTime==0) Then
				DEBUG("Warmup Ping() error: " & _GetPingErr($_error))
			Else
				DEBUG("Warmup ping: " & $_iResponseTime & "ms")
				If $_INTERVAL Then Sleep($_iInterval)
			EndIf
		EndIf


		; PING HOST AND COLLECT STATS
		For $i = 1 To $_iCount

			$_iResponseTime = Ping($_H, $_iTimeout)
			$_error = @error	; 1 = Host is offline, 2 = Host is unreachable (timeout), 3 = Bad destination, 4 = Other errors
			If (Not ($_error==0)) Or ($_iResponseTime==0) Then
				DEBUG("Ping() error: " & _GetPingErr($_error))
				ContinueLoop
			EndIf

			DEBUG($i & ": " & $_iResponseTime & "ms")


			$PingReceived += 1						; increase the counter for number of ping replies
			__CalcPingMinMax($_iResponseTime)		; stores Min and Max values
			__CalcPingJitter($_iResponseTime)		; calculates jitter
			$PingTotal += $_iResponseTime			; sum of all ping values

			; we skip Sleep() on the last ping
			If ($i<$_iCount) And $_INTERVAL Then Sleep($_iInterval)

		Next

		$WARNING_STATUS = __CalcPacketLoss($_iCount)
		$ERROR_STATUS   = __CalcPingValues($_iCount)
		If $ERROR_STATUS Then SetError(1)

	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; process AutoIt Ping() error code and returns releant error message
	; ===============================================================================================================================
	Func _GetPingErr($_iError)

		If StringIsDigit($_iError) Then
			$_iError = Number($_iError)
			Switch  $_iError
				Case 0
					Return SetError(0, 0, "Success")
				Case 1
					Return SetError(1, $_iError, "Host is offline")
				Case 2
					Return SetError(1, $_iError, "Host is unreachable")
				Case 3
					Return SetError(1, $_iError, "Bad destination")
				Case 4
					Return SetError(1, $_iError, "Other error")
				Case Else
					Return SetError(1, $_iError, "(Unknown error)")

			EndSwitch
		EndIf

		Return SetError(2, -1, "Unknown Error")	; if we managed to get here, something went wrong

	EndFunc


#EndRegion ### AutoIt Ping() RELATED STUFF ###


#Region ### VARIABLE PROCESSING ###


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Sets packet loss value based on number of pings sent, and number received.
	; Requires Global vars: $PingReceived, $PingPacketLoss
	; ===============================================================================================================================
	Func __CalcPacketLoss($_iPingNum)
		Local $_ERR = False
		$PingLost = $_iPingNum - $PingReceived
		$PingPacketLoss = ($PingLost / $_iPingNum) * 100
		If ($PingPacketLoss<>0) Then $_ERR = True
		Return $_ERR
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Sets latency average, min, max, and jitter values.
	; Requires Global vars: $PingReceived, $PingLost, $PingTotal, $PingTotalJitter
	;                       $PingTimeAvg, $PingTimeMin, $PingTimeMax, $PingJitter
	; ===============================================================================================================================
	Func __CalcPingValues($_iPingNum)
		Local $_ERR = False
		If ($PingLost = $_iPingNum) Then
			$PingTimeAvg = ""
			$PingTimeMin = ""
			$PingTimeMax = ""
			$PingJitter = ""
			$_ERR = True
		Else
			$PingTimeAvg = $PingTotal / $PingReceived
			If ($PingTotalJitter > 0) Then $PingJitter = $PingTotalJitter / ($PingReceived-1)
		EndIf
		Return $_ERR
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Sets latency min and max values.
	; Requires Global vars: $PingTimeMin, $PingTimeMax
	; ===============================================================================================================================
	Func __CalcPingMinMax($_iPing)
		If StringIsSpace($_iPing) Then Return SetError(1)
		If ($_iPing < $PingTimeMin) Then $PingTimeMin = $_iPing
		If ($_iPing > $PingTimeMax) Then $PingTimeMax = $_iPing
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Sets jitter value. Note that this calucation is pointless unless there are a significant number of ping samples to work with.
	; Requires Global vars: $PingReceived, $PingTimeJitter, $PingPrevPingTime, $PingTotalJitter
	; Ref: https://www.pingman.com/kb/article/what-is-jitter-57.html
	;      http://www.voiptroubleshooter.com/indepth/jittersources.html
	; ===============================================================================================================================
	Func __CalcPingJitter($_iPing)
		If StringIsSpace($_iPing) Then Return SetError(1)
		; from ping reply no. 2 we start working on jitter times
		If ($PingReceived >= 2) Then $PingTimeJitter = Abs($_iPing - $PingPrevPingTime)
		; we store the current ping value so we can use it again on the next run
		$PingPrevPingTime = $_iPing
		; total jitter time
		$PingTotalJitter = $PingTotalJitter + $PingTimeJitter
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; The inet_ntoa function converts an (Ipv4) Internet network address into an ASCII string in Internet standard dotted-decimal
	; format i.e. i.e. "16843009" >> "1.1.1.1"
	; Ref: https://docs.microsoft.com/en-us/windows/win32/api/wsipv6ok/nf-wsipv6ok-inet_ntoa
	; ===============================================================================================================================
	Func __inet_ntoa($_ulAddr)
	  Local $_sAddr =  DllCall("ws2_32.dll","STR","inet_ntoa", "UINT", $_ulAddr)
		If Not (@error==0) Then Return SetError(@error, 0, "0.0.0.0")
	  Return $_sAddr[0]
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; The inet_addr function converts a string containing an IPv4 dotted-decimal address into a proper address for the IN_ADDR
	; structure. If no error occurs, the inet_addr function returns an unsigned long value containing a suitable binary
	; representation of the Internet address given i.e. "1.1.1.1" >> "16843009"
	; Ref: https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-inet_addr
	; ===============================================================================================================================
	Func __inet_addr($_sAddr)
		Local $_ulAddr =  DllCall("ws2_32.dll","UINT","inet_addr", "STR", $_sAddr)
		If Not (@error==0) Then Return SetError(@error, 0, -1)	; INADDR_NONE
		Return $_ulAddr[0]
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; process WMI/DLL StatusCode integer and returns statuscode message string
	; sets @extended to integer StatusCode value (set to -1 if unknown error)
	; sets @error to non-zero if error
	; ===============================================================================================================================
	Func __GetStatusMsg($_iStatusCode)

		If StringIsDigit($_iStatusCode) Then
			$_iStatusCode = Number($_iStatusCode)
			Switch  $_iStatusCode
				Case 0
					Return SetError(0, 0, "Success")
				Case 11001
					Return SetError(1, $_iStatusCode, "Buffer Too Small")
				Case 11002
					Return SetError(1, $_iStatusCode, "Destination Net Unreachable")
				Case 11003
					Return SetError(1, $_iStatusCode, "Destination Host Unreachable")
				Case 11004
					Return SetError(1, $_iStatusCode, "Destination Protocol Unreachable")
				Case 11005
					Return SetError(1, $_iStatusCode, "Destination Port Unreachable")
				Case 11006
					Return SetError(1, $_iStatusCode, "No Resources")
				Case 11007
					Return SetError(1, $_iStatusCode, "Bad Option")
				Case 11008
					Return SetError(1, $_iStatusCode, "Hardware Error")
				Case 11009
					Return SetError(1, $_iStatusCode, "Packet Too Big")
				Case 11010
					Return SetError(1, $_iStatusCode, "Request Timed Out")
				Case 11011
					Return SetError(1, $_iStatusCode, "Bad Request")
				Case 11012
					Return SetError(1, $_iStatusCode, "Bad Route")
				Case 11013
					Return SetError(1, $_iStatusCode, "TimeToLive Expired Transit")
				Case 11014
					Return SetError(1, $_iStatusCode, "TimeToLive Expired Reassembly")
				Case 11015
					Return SetError(1, $_iStatusCode, "Parameter Problem")
				Case 11016
					Return SetError(1, $_iStatusCode, "Source Quench")
				Case 11017
					Return SetError(1, $_iStatusCode, "Option Too Big")
				Case 11018
					Return SetError(1, $_iStatusCode, "Bad Destination")
				Case 11032
					Return SetError(1, $_iStatusCode, "Negotiating IPSEC")
				Case 11050
					Return SetError(1, $_iStatusCode, "General Failure")
				Case Else
					Return SetError(1, -1, "Unknown StatusCode: " & $_iStatusCode)
			EndSwitch
		EndIf

		Return SetError(2, -1, "Unknown Error")	; if we managed to get here, something went wrong

	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Checks env variable, and return a default value if env var is not set
	; ===============================================================================================================================
	Func _EnvGet($_envVar, $_sDefault = "")
		Local $_value = EnvGet($_envVar)
		If Not StringIsSpace($_value) Then Return $_value
		Return $_sDefault
	EndFunc


#EndRegion ### VARIABLE PROCESSING ###


#Region ### ECHO DEBUG ERROR - CONSOLE OUTPUT ###

	; Collection of small functions to make output to the console easier

	Func ECHO($STDOUT = "")
		ConsoleWrite($STDOUT & @CRLF)
	EndFunc

	Func ECHOBR($STDOUT = "", $STDOUTDATA = "")
		ConsoleWrite($STDOUT & " = [" & $STDOUTDATA & "]" & @CRLF)
	EndFunc


	Func DEBUG($STDOUT = "")
		If $_D Then ConsoleWrite($STDOUT & @CRLF)
	EndFunc

	Func DEBUGBR($STDOUT = "", $STDOUTDATA = "")
		If $_D Then ConsoleWrite($STDOUT & " = [" & $STDOUTDATA & "]" & @CRLF)
	EndFunc


	Func ERROR($STDERR = "")
		ConsoleWriteError($STDERR & @CRLF)
	EndFunc

	Func ERRORBR($STDERR = "", $STDERRDATA = "")
		ConsoleWriteError($STDERR & " = [" & $STDERRDATA & "]" & @CRLF)
	EndFunc

#EndRegion ### ECHO DEBUG ERROR - CONSOLE OUTPUT ###


Func _PrintHelp()

	Local Const $_FILEVERSION = FileGetVersion(@AutoItExe)
	Local Const $_FILEDESC = FileGetVersion(@AutoItExe, "FileDescription")
	Local Const $_FILECOMMENT = FileGetVersion(@AutoItExe, "Comments")

	If @Compiled Then		; Note: FileVersion and FileDescription will report "AutoIt v3 Script - v3.3.14.5" if not compiled as executable
		ECHO()
		ECHO($_FILEDESC & " - v" & $_FILEVERSION)
	EndIf

	ECHO()
	ECHO("Usage: SENSOR-PingPong.exe [-h:<target_name>] [-m:<method>] [-f:<prefix>]")
	ECHO("                           [-n:<count>] [-w:<timeout>] [-i:<interval>] [-g]")
	ECHO("                           [-c] [-d]")
	ECHO()
	ECHO("Options:")
	ECHO("    -h    Destination hostname or IPv4 number.")
	ECHO("          Note: env var %prtg_host% will be used if argument is omitted.")
	ECHO("    -m    (wmi | ms | dll | autoit) Method of ping. Default is dll (Windows")
	ECHO("          IP Helper API).")
	ECHO("    -f    Channel names prefixes.")
	ECHO("    -n    Number of echo requests to send (default 10).")
	ECHO("    -w    Timeout in milliseconds to wait for each reply (default 4000).")
	ECHO("    -i    Interval in milliseconds. Specify 0 for fast ping (default 500).")
	ECHO("    -g    Do not send the warmup ping.")
	ECHO("    -c    Do not add XML prolog and PRTG root elements to output (only show")
	ECHO("          the channels).")
	ECHO("    -d    Debug mode.")
	ECHO()

	If @Compiled Then		; Note: FileVersion and FileDescription will report "AutoIt v3 Script - v3.3.14.5" if not compiled as executable
		ECHO($_FILECOMMENT)
		ECHO()
	EndIf


EndFunc


Func OnExit()

	TCPShutdown()
	DEBUG("SCRIPT DONE: " & Round(TimerDiff($hScriptTimer),3) & "ms")

EndFunc
