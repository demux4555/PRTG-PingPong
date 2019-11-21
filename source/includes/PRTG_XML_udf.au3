#include-once

; #DESCRIPTION# =================================================================================================================
; Title .........: PRTG XML channel output UDF
; Description ...: UDF to allow easier output of PRTG channels in XML format.
; Author(s) .....: demux4555
; Changelog .....:
;	v3.00	2019.11.19	Proper code cleanup.
; Notes .........: Global Bool var $_CHAONLY can be used to determine if XML prolog and PRTG root elements should be included
;                  in output when using _PrtgShowXML().
;                  Global Bool vars $_D and $_DD can be used for debugging.
; ===============================================================================================================================


If Not IsDeclared("_CHAONLY") Then Global $_CHAONLY = False	; for _PrtgShowXML()


#Region ### CONSTANTS FOR PRTG XML TAGS ###


	; $_dOpts in _PrtgChannel(). Use any combination.
	Global Const $PRTG_UNIT_CUSTOM			= 2^0		; <Unit> 		... The unit of the value. Default is Custom. Useful for PRTG to be able to convert volumes and times.
	Global Const $PRTG_UNIT_BYTESBANDWIDTH	= 2^1		; ....
	Global Const $PRTG_UNIT_BYTESMEMORY		= 2^2		; ..
	Global Const $PRTG_UNIT_BYTESDISK		= 2^3		; .
	Global Const $PRTG_UNIT_TEMPERATURE		= 2^4		; .
	Global Const $PRTG_UNIT_PERCENT			= 2^5		; .
	Global Const $PRTG_UNIT_TIMERESPONSE	= 2^6		; .
	Global Const $PRTG_UNIT_TIMESECONDS		= 2^7		; .
	Global Const $PRTG_UNIT_COUNT			= 2^8		; .
	Global Const $PRTG_UNIT_CPU 			= 2^9		; .
	Global Const $PRTG_UNIT_BYTESFILE		= 2^10		; .
	Global Const $PRTG_UNIT_SPEEDDISK		= 2^11		; .
	Global Const $PRTG_UNIT_SPEEDNET		= 2^12		; .
	Global Const $PRTG_UNIT_TIMEHOURS		= 2^13		; .
	Global Const $PRTG_MODE_ABSOLUTE		= 2^14		; <Mode> 		... Selects if the value is a absolute value or counter. Default is Absolute.
	Global Const $PRTG_MODE_DIFFERENCE		= 2^15		; ^
	Global Const $PRTG_FLOAT_NO				= 2^16		; <Float> 		... Define if the value is a float. Default is 0 (no). If set to 1 (yes), use a dot as decimal separator in values. Note: Define decimal places with the <DecimalMode> element.
	Global Const $PRTG_FLOAT_YES			= 2^17		; ^
	Global Const $PRTG_DECIMALMODE_AUTO		= 2^18		; <DecimalMode> ... Init value for the Decimal Places option. If 0 is used in the <Float> element (i.e. use integer), the default is Auto; otherwise (i.e. for float) default is All. Note: You can change this initial setting later in the Channel settings of the sensor.
	Global Const $PRTG_DECIMALMODE_ALL		= 2^19		; ^
	Global Const $PRTG_WARNING_NO			= 2^20		; <Warning> 	... If enabled for at least one channel, the entire sensor is set to warning status. Default is 0 (no).
	Global Const $PRTG_WARNING_YES			= 2^21		; ^
	Global Const $PRTG_SHOWCHART_YES		= 2^22		; <ShowChart> 	... Init value for the Show in Graph option. Default is 1 (yes).
	Global Const $PRTG_SHOWCHART_NO			= 2^23		; ^
	Global Const $PRTG_SHOWTABLE_YES		= 2^24		; <ShowTable> 	... Init value for the Show in Table option. Default is 1 (yes).
	Global Const $PRTG_SHOWTABLE_NO			= 2^25		; ^
	Global Const $PRTG_LIMITMODE_NO			= 2^26		; <LimitMode> 	... Define if the limit settings defined above will be active. Default is 0 (no; limits inactive). If 0 is used the limits will be written to the sensor channel settings as predefined values, but limits will be disabled.
	Global Const $PRTG_LIMITMODE_YES		= 2^27		; ^
	Global Const $PRTG_NOTIFYCHANGED		= 2^28		; <NotifyChanged> ... If a returned channel contains this tag, it will trigger a change notification that you can use with the Change Trigger to send a notification. 	No content required.
	Global Const $PRTG_DONTPRINT			= -1		; Custom setting: excludes the channel from being printed, making it suitable for simply storing values. Note: not a bit value, cannot be added with other values and must be used alone.

	; $_dSpeedVolume in _PrtgChannel(). Select one.
	Global Const $PRTG_SPEEDSIZE_ONE		= 2^0		; <SpeedSize> ... Size used for the display value. For example, if you have a value of 50000 and use Kilo as size the display is 50 kilo # . Default is One (value used as returned). For the Bytes and Speed units this is overridden by the setting in the user interface.
	Global Const $PRTG_SPEEDSIZE_KILO		= 2^1
	Global Const $PRTG_SPEEDSIZE_MEGA		= 2^2
	Global Const $PRTG_SPEEDSIZE_GIGA		= 2^3
	Global Const $PRTG_SPEEDSIZE_TERA		= 2^4
	Global Const $PRTG_SPEEDSIZE_BYTE		= 2^5
	Global Const $PRTG_SPEEDSIZE_KILOBYTE	= 2^6
	Global Const $PRTG_SPEEDSIZE_MEGABYTE	= 2^7
	Global Const $PRTG_SPEEDSIZE_GIGABYTE	= 2^8
	Global Const $PRTG_SPEEDSIZE_TERABYTE	= 2^9
	Global Const $PRTG_SPEEDSIZE_BIT		= 2^10
	Global Const $PRTG_SPEEDSIZE_KILOBIT	= 2^11
	Global Const $PRTG_SPEEDSIZE_MEGABIT	= 2^12
	Global Const $PRTG_SPEEDSIZE_GIGABIT	= 2^13
	Global Const $PRTG_SPEEDSIZE_TERABIT	= 2^14

	; Select one, and add to $PRTG_SPEEDSIZE_xxxx above
	Global Const $PRTG_SPEEDTIME_SECOND		= 2^15			; <SpeedTime>... See above, used when displaying the speed. Default is Second.
	Global Const $PRTG_SPEEDTIME_MINUTE		= 2^16
	Global Const $PRTG_SPEEDTIME_HOUR		= 2^17
	Global Const $PRTG_SPEEDTIME_DAY		= 2^18

	; Select one, and add to $PRTG_SPEEDSIZE_xxxx above
	Global Const $PRTG_VOLUMESIZE_ONE			= 2^20			; <VolumeSize> ... Size used for the display value. For example, if you have a value of 50000 and use Kilo as size the display is 50 kilo # . Default is One (value used as returned). For the Bytes and Speed units this is overridden by the setting in the user interface.
	Global Const $PRTG_VOLUMESIZE_KILO			= 2^21
	Global Const $PRTG_VOLUMESIZE_MEGA			= 2^22
	Global Const $PRTG_VOLUMESIZE_GIGA			= 2^23
	Global Const $PRTG_VOLUMESIZE_TERA			= 2^24
	Global Const $PRTG_VOLUMESIZE_BYTE			= 2^25
	Global Const $PRTG_VOLUMESIZE_KILOBYTE		= 2^26
	Global Const $PRTG_VOLUMESIZE_MEGABYTE		= 2^27
	Global Const $PRTG_VOLUMESIZE_GIGABYTE		= 2^28
	Global Const $PRTG_VOLUMESIZE_TERABYTE		= 2^29
	Global Const $PRTG_VOLUMESIZE_BIT			= 2^30
	Global Const $PRTG_VOLUMESIZE_KILOBIT		= 2^31
	Global Const $PRTG_VOLUMESIZE_MEGABIT		= 2^32
	Global Const $PRTG_VOLUMESIZE_GIGABIT		= 2^33
	Global Const $PRTG_VOLUMESIZE_TERABIT		= 2^34

	; PRTG Custom Sensor bit combos commonly used *** WIP ***
	; These are mostly for convenience.
	Global Const $PRTG_CS_HIDE		= $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO																	; hide both chart and table
	Global Const $PRTG_CS_PERCENT 	= $PRTG_UNIT_PERCENT + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO	; percentage (%)
	Global Const $PRTG_CS_TEMP 		= $PRTG_UNIT_TEMPERATURE + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_ALL											; temperature (C)
	Global Const $PRTG_CS_CPULOAD 	= $PRTG_UNIT_PERCENT + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO												; cpu load usage percentage (%)
	Global Const $PRTG_CS_CPULA 	= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_ALL + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO		; cpu load average (float)
	Global Const $PRTG_CS_HZ 		= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_ALL + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO		; frequency/hertz (Hz)
	Global Const $PRTG_CS_VAC 		= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_ALL + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO		; voltage (VAC)
	Global Const $PRTG_CS_UPTIME 	= $PRTG_UNIT_TIMESECONDS + $PRTG_SHOWTABLE_NO																; uptime (seconds)
	Global Const $PRTG_CS_UPTIME_HIDE   = $PRTG_UNIT_TIMESECONDS + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO										; uptime (seconds) hidden
	Global Const $PRTG_CS_SECONDS_CHART	= $PRTG_UNIT_TIMESECONDS + $PRTG_SHOWTABLE_NO 															; (seconds) no table
	Global Const $PRTG_CS_MEM 		= $PRTG_UNIT_BYTESMEMORY																					; memory used (bytes)
	Global Const $PRTG_CS_MEM_HIDE	= $PRTG_UNIT_BYTESMEMORY + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO											; memory used (bytes)
	Global Const $PRTG_CS_FREESPACE	= $PRTG_UNIT_BYTESDISK																						; disk free space (bytes)
	Global Const $PRTG_CS_LATENCY	= $PRTG_UNIT_TIMERESPONSE + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO										; Ping response time, latency, jitter, etc (ms)
	Global Const $PRTG_CS_EXECTIME	= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO + $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO	; Sensor Execution Time (sec)
	Global Const $PRTG_CS_AMPERE	= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO												; current/ampere (A)
	Global Const $PRTG_CS_VA		= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO												; volt-ampere (VA)
	Global Const $PRTG_CS_VOLT		= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO 												; voltage (V)
	Global Const $PRTG_CS_POWER		= $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO 												; power/watt (W)
	Global Const $PRTG_CS_WATTHOUR_NOW = $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO+$PRTG_MODE_DIFFERENCE 					; energy (Wh)
	Global Const $PRTG_CS_WATTHOUR_AVG = $PRTG_UNIT_CUSTOM + $PRTG_FLOAT_YES + $PRTG_DECIMALMODE_AUTO 											; energy (Wh)
	Global Const $PRTG_CS_OVL		= $PRTG_SHOWCHART_NO + $PRTG_SHOWTABLE_NO 																	; lookup
	Global Const $PRTG_CS_DONTPRINTCHANNEL = $PRTG_DONTPRINT


#EndRegion ### CONSTANTS FOR PRTG XML TAGS ###


#Region ### XML OUTPUT ###


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _PrtgChannel
	; Description ...: Outputs a PRTG channel in XML Return Format.
	; Syntax ........: _PrtgChannel($_sChannel, $_vValueVar[, $_sCustomUnit = "#"[, $_dOpts = $PRTG_UNIT_CUSTOM[, $_sValueLookup = Null[,
	;                  $_dSpeedVolume = 0[, $_iLimitMaxError = Null[, $_iLimitMaxWarning = Null[, $_iLimitMinWarning = Null[,
	;                  $_iLimitMinError = Null[, $_sLimitErrorMsg = Null[, $_sLimitWarningMsg = Null]]]]]]]]]])
	; Parameters ....: $_sChannel           - Name of the channel as displayed in user interfaces. This parameter is required and
	;                                         must be unique for the sensor.
	;                  $_vValueVar          - Channel value (64-bit integer or float).
	;                  $_sCustomUnit        - [optional] If Custom is used as unit, this is the text displayed behind the value.
	;                                         Default is "#".
	;                  $_dOpts              - [optional] Channel settings. Default is $PRTG_UNIT_CUSTOM. See Gobal Const vars above.
	;                  $_sValueLookup       - [optional] Define if you want to use a lookup file  Enter the ID of the lookup file
	;                                         that you want to use, or omit this element to not use lookups. Default is Null.
	;                  $_dSpeedVolume       - [optional] Size and time unit used for the display value. Default is 0.
	;                  $_iLimitMaxError     - [optional] Define an upper error limit for the channel. Default is Null.
	;                  $_iLimitMaxWarning   - [optional] Define an upper warning limit for the channel. Default is Null.
	;                  $_iLimitMinWarning   - [optional] Define a lower warning limit for the channel. Default is Null.
	;                  $_iLimitMinError     - [optional] Define a lower error limit for the channel. Default is Null.
	;                  $_sLimitErrorMsg     - [optional] Define an additional message (for Error state). Default is Null.
	;                  $_sLimitWarningMsg   - [optional] Define an additional message (for Warning state). Default is Null.
	; Return values .: No. Only for internal debug purposes.
	; Author ........: demux4555
	; Remarks .......: You need to read (and understand) PRTG's API and custom sensors feature before implementing this.
	;                  This function will output the channel, even if its value is blank "". Set value to Null to omit (skip)
	;                  channel in output.
	; Link ..........:
	; References ....: https://www.paessler.com/manuals/prtg/custom_sensors
	; Examples ......: No
	; ===============================================================================================================================
	Func _PrtgChannel($_sChannel, $_vValueVar, $_sCustomUnit = "#", $_dOpts = $PRTG_UNIT_CUSTOM, $_sValueLookup = Null, $_dSpeedVolume = 0, $_iLimitMaxError = Null, $_iLimitMaxWarning = Null, $_iLimitMinWarning = Null, $_iLimitMinError = Null, $_sLimitErrorMsg = Null, $_sLimitWarningMsg = Null)

		If ($_vValueVar==Null) Then Return SetError(0, 0, 1)				; we can disable the output of the channel entirely if $_vValueVar is set to Null
		If ($_dOpts==Null) Or ($_dOpts==-1) Then Return SetError(0, 0, 1)	; dont print channel in output

		If StringIsSpace($_sChannel) Then Return SetError(1, 0, 0)

		; ensuring we enable default values if "" or 0 is used in arguments
		If StringIsSpace($_dOpts) Or ($_dOpts==0) Or ($_dOpts==Default) Then $_dOpts = $PRTG_UNIT_CUSTOM	; we fall back to "Custom" as default
		If ($_sCustomUnit==Null) Then
			$_sCustomUnit = ""
		ElseIf ($_sCustomUnit==Default) Then
			$_sCustomUnit = "#"
		EndIf
		If ($_sValueLookup=="") 	Or ($_sValueLookup==Default) 	 Then $_sValueLookup = Null
		If ($_iLimitMaxError=="") 	Or ($_iLimitMaxError==Default) 	 Then $_iLimitMaxError = Null
		If ($_iLimitMaxWarning=="") Or ($_iLimitMaxWarning==Default) Then $_iLimitMaxWarning = Null
		If ($_iLimitMinWarning=="") Or ($_iLimitMinWarning==Default) Then $_iLimitMinWarning = Null
		If ($_iLimitMinError=="") 	Or ($_iLimitMinError==Default) 	 Then $_iLimitMinError = Null
		If ($_sLimitErrorMsg=="") 	Or ($_sLimitErrorMsg==Default) 	 Then $_sLimitErrorMsg = Null
		If ($_sLimitWarningMsg=="") Or ($_sLimitWarningMsg==Default) Then $_sLimitWarningMsg = Null

		Local $_Unit = "Custom", $_Mode = Null, $_Float = Null, $_DecimalMode = Null, $_Warning = Null, $_ShowChart = Null, $_ShowTable = Null, $_NotifyChanged = Null
		Local $_SpeedSize = Null, $_SpeedTime = Null, $_VolumeSize = Null, $_LimitMode = Null
		Local Const $TAB = "    ", $TAB2 = $TAB & $TAB

		$_sChannel  = StringStripWS($_sChannel, 7) 				; strip leading/trailing/double spaces from the channel name
		If (StringLeft($_vValueVar, 1) == "$") Then				; if there is a leading $ it means it's a variable name (as opposed to using the value of the var)...
			$_vValueVar = StringTrimLeft($_vValueVar, 1)		; ... remove the $ in the variable name
			$_vValueVar = Execute('$' & $_vValueVar)			; ... using Execute() as opposed to Eval() as this allows parsing of arrays[][]
		EndIf

		; <Unit> and <CustomUnit>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_CUSTOM)
				$_Unit = "Custom"
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_BYTESBANDWIDTH)
				$_Unit = "BytesBandwidth"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_BYTESMEMORY)
				$_Unit = "BytesMemory"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_BYTESDISK)
				$_Unit = "BytesDisk"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_TEMPERATURE)
				$_Unit = "Temperature"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_PERCENT)
				$_Unit = "Percent"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_TIMERESPONSE)
				$_Unit = "TimeResponse"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_TIMESECONDS)
				$_Unit = "TimeSeconds"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_COUNT)
				$_Unit = "Count"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_CPU)
				$_Unit = "CPU"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_BYTESFILE)
				$_Unit = "BytesFile"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_SPEEDDISK)
				$_Unit = "SpeedDisk"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_SPEEDNET)
				$_Unit = "SpeedNet"
				$_sCustomUnit = Null
			Case _PRTGOPT($_dOpts, $PRTG_UNIT_TIMEHOURS)
				$_Unit = "TimeHours"
				$_sCustomUnit = Null
		EndSelect


		; >>> -DD debug mode with XML tags removed for super compact debug output
		If (Eval("_D")=True) And (Eval("_DD")=True) Then 						; checks $_D and $_DD status... command line arguments -D and -DD
			ConsoleWrite('    ['&$_sChannel&']  =  ['&$_vValueVar&']  ' & @TAB & @TAB & (($_sCustomUnit=Null) ? ($_Unit) : ("'" & $_sCustomUnit & "'")) & @CRLF)		; output i.e. "[channel name] = [value]  CustomUnit"
			Return 1 ; quit
		EndIf


		; <Mode>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_MODE_ABSOLUTE)
				$_Mode = "Absolute"
			Case _PRTGOPT($_dOpts, $PRTG_MODE_DIFFERENCE)
				$_Mode = "Difference"
		EndSelect

		; <Flaot>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_FLOAT_NO)
				$_Float			= "0"
			Case _PRTGOPT($_dOpts, $PRTG_FLOAT_YES)
				$_Float 		= "1"
		EndSelect

		; <DecimalMode>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_DECIMALMODE_AUTO)
				$_DecimalMode = "Auto"
			Case _PRTGOPT($_dOpts, $PRTG_DECIMALMODE_ALL)
				$_DecimalMode = "All"
		EndSelect

		; <Warning>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_WARNING_NO)
				$_Warning = "0"
			Case _PRTGOPT($_dOpts, $PRTG_WARNING_YES)
				$_Warning = "1"
		EndSelect

		; <ShowChart>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_SHOWCHART_YES)
				$_ShowChart = "1"
			Case _PRTGOPT($_dOpts, $PRTG_SHOWCHART_NO)
				$_ShowChart = "0"
		EndSelect

		; <ShowTable>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_SHOWTABLE_YES)
				$_ShowTable = "1"
			Case _PRTGOPT($_dOpts, $PRTG_SHOWTABLE_NO)
				$_ShowTable = "0"
		EndSelect

		; <LimitMode>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_LIMITMODE_NO)		; Default is 0 (no; limits inactive). If 0 is used the limits will be written to the sensor channel settings as predefined values, but limits will be disabled.
				$_LimitMode = "0"
			Case _PRTGOPT($_dOpts, $PRTG_LIMITMODE_YES)
				$_LimitMode = "1"
		EndSelect

		; <NotifyChanged>
		Select
			Case _PRTGOPT($_dOpts, $PRTG_NOTIFYCHANGED)
				$_NotifyChanged = "1"
		EndSelect

		; <SpeedSize>
		Select
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_ONE)
				$_SpeedSize = "One"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_KILO)
				$_SpeedSize = "Kilo"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_MEGA)
				$_SpeedSize = "Mega"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_GIGA)
				$_SpeedSize = "Giga"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_TERA)
				$_SpeedSize = "Tera"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_BYTE)
				$_SpeedSize = "Byte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_KILOBYTE)
				$_SpeedSize = "KiloByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_MEGABYTE)
				$_SpeedSize = "MegaByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_GIGABYTE)
				$_SpeedSize = "GigaByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_TERABYTE)
				$_SpeedSize = "TeraByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_BIT)
				$_SpeedSize = "Bit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_KILOBIT)
				$_SpeedSize = "KiloBit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_MEGABIT)
				$_SpeedSize = "MegaBit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_GIGABIT)
				$_SpeedSize = "GigaBit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDSIZE_TERABIT)
				$_SpeedSize = "TeraBit"
		EndSelect

		; <SpeedTime>
		Select
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDTIME_SECOND)
				$_SpeedTime = "Second"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDTIME_MINUTE)
				$_SpeedTime = "Minute"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDTIME_HOUR)
				$_SpeedTime = "Hour"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_SPEEDTIME_DAY)
				$_SpeedTime = "Day"
		EndSelect

		; <VolumeSize>
		Select
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_ONE)
				$_VolumeSize = "One"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_KILO)
				$_VolumeSize = "Kilo"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_MEGA)
				$_VolumeSize = "Mega"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_GIGA)
				$_VolumeSize = "Giga"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_TERA)
				$_VolumeSize = "Tera"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_BYTE)
				$_VolumeSize = "Byte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_KILOBYTE)
				$_VolumeSize = "KiloByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_MEGABYTE)
				$_VolumeSize = "MegaByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_GIGABYTE)
				$_VolumeSize = "GigaByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_TERABYTE)
				$_VolumeSize = "TeraByte"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_BIT)
				$_VolumeSize = "Bit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_KILOBIT)
				$_VolumeSize = "KiloBit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_MEGABIT)
				$_VolumeSize = "MegaBit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_GIGABIT)
				$_VolumeSize = "GigaBit"
			Case _PRTGOPT($_dSpeedVolume, $PRTG_VOLUMESIZE_TERABIT)
				$_VolumeSize = "TeraBit"
		EndSelect

		; >>> OUTPUT THE CHANNEL
		; Note: Only Tags that are <> Null will be shown
		ConsoleWrite($TAB & '<result>' & @CRLF)
		_PrtgPrintTag("Channel", $_sChannel) 	; this will always be shown in a channel
		_PrtgPrintTag("Value", $_vValueVar) 	; this will always be shown in a channel
		_PrtgPrintTag("Unit", $_Unit)
		_PrtgPrintTag("CustomUnit", $_sCustomUnit)
		_PrtgPrintTag("SpeedSize", $_SpeedSize)
		_PrtgPrintTag("VolumeSize", $_VolumeSize)
		_PrtgPrintTag("SpeedTime", $_SpeedTime)
		_PrtgPrintTag("Mode", $_Mode)
		_PrtgPrintTag("Float", $_Float)
		_PrtgPrintTag("DecimalMode", $_DecimalMode)
		_PrtgPrintTag("Warning", $_Warning)
		_PrtgPrintTag("ShowChart", $_ShowChart)
		_PrtgPrintTag("ShowTable", $_ShowTable)
		_PrtgPrintTag("LimitMaxError", $_iLimitMaxError)
		_PrtgPrintTag("LimitMaxWarning", $_iLimitMaxWarning)
		_PrtgPrintTag("LimitMinWarning", $_iLimitMinWarning)
		_PrtgPrintTag("LimitMinError", $_iLimitMinError)
		_PrtgPrintTag("LimitErrorMsg", $_sLimitErrorMsg)
		_PrtgPrintTag("LimitWarningMsg", $_sLimitWarningMsg)
		_PrtgPrintTag("LimitMode", $_LimitMode)
		_PrtgPrintTag("ValueLookup", $_sValueLookup)
		_PrtgPrintTag("NotifyChanged", $_NotifyChanged)
		ConsoleWrite($TAB & '</result>' & @CRLF)

		Return 1

	EndFunc


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _PrtgPrintTag
	; Description ...: Output an XML element's opening and closing tags, with its content
	; Syntax ........: _PrtgPrintTag($_sTag[, $_sContent = ""])
	; Parameters ....: $_sTag               - The tag to be used for the XML element.
	;                  $_sContent           - [optional] The contents of the XML element. Use value Null to omit the output of the
	;                                         XML element alltogether. Default is "".
	; Return values .: None. Used for debug purposed only.
	; Author ........: demux4555
	; Remarks .......: Does not validate tag names, or content. XML output will be invalid if entity references are not used.
	; Reference .....: https://www.w3schools.com/xml/xml_syntax.asp
	; ===============================================================================================================================
	Func _PrtgPrintTag($_sTag, $_sContent = "")
		If ($_sContent == Null) Or StringIsSpace($_sTag) Then Return SetError(1, 0, "")			; we allow an empty text string (shows tags, but no content)
		ConsoleWrite("        " & '<' & $_sTag & '>' & $_sContent & '</' & $_sTag & '>' & @CRLF)
	EndFunc


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _PrtgComment
	; Description ...: Output an XML comment
	; Syntax ........: _PrtgComment([$_sCommentText = ""])
	; Parameters ....: $_sCommentText       - [optional] Comment string. Default is "".
	; Return values .: None
	; Author ........: demux4555
	; Remarks .......: Automatically replaces double dashes "--" with a single dash to avoid invalid comment formatting.
	; Reference .....: https://www.w3schools.com/xml/xml_syntax.asp
	; ===============================================================================================================================
	Func _PrtgComment($_sCommentText = "")
		If StringIsSpace($_sCommentText) Then Return
		$_sCommentText = StringReplace($_sCommentText, "--", "-")	; Two dashes in the middle of a comment are not allowed, so we replace with a single dash
		ConsoleWrite("    <!--" & $_sCommentText & "-->" & @CRLF)
	EndFunc


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _PrtgShowXML
	; Description ...: Output/omit XML prolog and PRTG root element, allowing embedding of the sensor in bat files with multiple sensors.
	; Syntax ........: _PrtgShowXML()
	; Parameters ....: None
	; Return values .: None
	; Author ........: demux4555
	; Remarks .......: Will only output XML prolog header/footer if Global var $_CHAONLY is set to False
	;                  To be used twice; once before the first _PrtgChannel(), and then again after the final channel/comment is done.
	; Reference .....: https://www.paessler.com/manuals/prtg/custom_sensors#advanced_sensors
	; ===============================================================================================================================
	Func _PrtgShowXML()
		If (Eval("_CHAONLY")=True) Then Return				; Global var $_CHAONLY ... we skip if we're only showing the channels

		Local $_END = Eval("____XML_status")				; this is an internal Global var to check if we're outputting start or end XML tags
		If ($_END<>1) Then
			ConsoleWrite(	'<?xml version="1.0" encoding="Windows-1252" ?>' & @CRLF & _	; XML prolog
							'<prtg>' & @CRLF & _											; PRTG root element
							@CRLF)
			Assign("____XML_status", 1, 2) 	; $ASSIGN_FORCEGLOBAL
		ElseIf ($_END=1) Then
			ConsoleWrite(	@CRLF & _
							'</prtg>' & _
							@CRLF)
			Assign("____XML_status", "", 2)	; $ASSIGN_FORCEGLOBAL
		EndIf
	EndFunc


	; #FUNCTION# ====================================================================================================================
	; Name ..........: _SecsToTime
	; Description ...: Convert seconds (i.e. uptime or drive PowerOn time) to human-readable years days hours mins seconds
	;                  (i.e. for use in status text)
	; Syntax ........: _SecsToTime([$_iSecs = 0[, $_compact = 0]])
	; Parameters ....: $_iSecs              - [optional] Seconds, as integer value. Default is 0.
	;                  $_compact            - [optional] Compact mode. Set to 1 to enable. Default is 0.
	; Return values .: Human readable time i.e. "1y 58d 0h 24m"
	; Author ........: demux4555
	; ===============================================================================================================================
	Func _SecsToTime($_iSecs = 0, $_compact = 0)
		If StringIsSpace($_iSecs) Then Return SetError(1, 0, "")
		$_iSecs = Int($_iSecs)
		Local $_sRet = ""
		Local Const $sY = "y ", $sD = "d ", $sH = "h ", $sM = "m ", $sS = "s"

		Local $_iYears = Floor($_iSecs/31536000)
		$_iSecs -= $_iYears*31536000
		Local $_iDays = Floor($_iSecs/86400)
		$_iSecs -= $_iDays*86400
		Local $_iHours = Floor($_iSecs/3600)
		$_iSecs -= $_iHours*3600
		Local $_iMins = Floor($_iSecs/60)
		$_iSecs -= Round($_iMins*60)

		If $_compact==1 Then
			$_iSecs = StringFormat("%02i", $_iSecs)
			$_iHours = StringFormat("%02i", $_iHours)
			$_iMins = StringFormat("%02i", $_iMins)
		EndIf

		Select
			Case $_iYears>0
				$_sRet = $_iYears & $sY & $_iDays & $sD & $_iHours & $sH & $_iMins & $sM
			Case $_iDays>0
				$_sRet = $_iDays & $sD & $_iHours & $sH & $_iMins & $sM
			Case $_iHours>0
				$_sRet =  $_iHours & $sH & $_iMins & $sM
			Case $_iMins>0
				$_sRet =  $_iMins & $sM & $_iSecs & $sS
			Case Else ; $_iSecs>0
				$_sRet =  $_iSecs & $sS
		EndSelect

		If $_compact==1 Then
			$_sRet = StringStripWS($_sRet, 8)	; strip all
		Else
			$_sRet = StringStripWS($_sRet, 1+2+4) ; strip lead/trail/double
		EndIf

		Return $_sRet

	EndFunc


#EndRegion ### XML OUTPUT ###


#Region ### PRTG OPTIONS AND BIT TRANSLATIONS ###


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Check if bit switch is enabled in bit options
	; Usage example: _PRTGOPT($dBits, $PRTG_SHOWCHART_YES)  will check to see if ShowChart should be enabled
	; Return: 1 if bit is set, 0 if bit is not set
	; ===============================================================================================================================
	Func _PRTGOPT($_dBits, $_dSWITCH)
		Return $_dSWITCH = BitAND($_dSWITCH, $_dBits)
	EndFunc


	; #INTERNAL_USE_ONLY# ===========================================================================================================
	; Returns bit value of specified Tag and Content
	; Example: _GetPRTGOPT("SpeedSize", "Kilobit") will Return 2048
	; ===============================================================================================================================
	Func _GetPRTGOPT($_sTag, $_sContent = "")
		If StringIsSpace($_sTag) Then Return SetError(1, 0, 0)

		Select

			Case $_sTag = "Unit"
				Select
					Case $_sContent = "Custom"
						Return $PRTG_UNIT_CUSTOM
					Case $_sContent = "BytesBandwidth"
						Return $PRTG_UNIT_BYTESBANDWIDTH
					Case $_sContent = "BytesMemory"
						Return $PRTG_UNIT_BYTESMEMORY
					Case $_sContent = "BytesDisk"
						Return $PRTG_UNIT_BYTESDISK
					Case $_sContent = "Temperature"
						Return $PRTG_UNIT_TEMPERATURE
					Case $_sContent = "Percent"
						Return $PRTG_UNIT_PERCENT
					Case $_sContent = "TimeResponse"
						Return $PRTG_UNIT_TIMERESPONSE
					Case $_sContent = "TimeSeconds"
						Return $PRTG_UNIT_TIMESECONDS
					Case $_sContent = "Count"
						Return $PRTG_UNIT_COUNT
					Case $_sContent = "CPU"
						Return $PRTG_UNIT_CPU
					Case $_sContent = "BytesFile"
						Return $PRTG_UNIT_BYTESFILE
					Case $_sContent = "SpeedDisk"
						Return $PRTG_UNIT_SPEEDDISK
					Case $_sContent = "SpeedNet"
						Return $PRTG_UNIT_SPEEDNET
					Case $_sContent = "TimeHours"
						Return $PRTG_UNIT_TIMEHOURS
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "Mode"
				Select
					Case $_sContent = "Absolute"
						Return $PRTG_MODE_ABSOLUTE
					Case $_sContent = "Difference"
						Return $PRTG_MODE_DIFFERENCE
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "Float"
				Select
					Case $_sContent == "0"
						Return $PRTG_FLOAT_NO
					Case $_sContent == "1"
						Return $PRTG_FLOAT_YES
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "DecimalMode"
				Select
					Case $_sContent = "Auto"
						Return $PRTG_DECIMALMODE_AUTO
					Case $_sContent = "All"
						Return $PRTG_DECIMALMODE_ALL
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "Warning"
				Select
					Case $_sContent == "0"
						Return $PRTG_WARNING_NO
					Case $_sContent == "1"
						Return $PRTG_WARNING_YES
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "ShowChart"
				Select
					Case $_sContent == "1"
						Return $PRTG_SHOWCHART_YES
					Case $_sContent == "0"
						Return $PRTG_SHOWCHART_NO
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "ShowTable"
				Select
					Case $_sContent == "1"
						Return $PRTG_SHOWTABLE_YES
					Case $_sContent == "0"
						Return $PRTG_SHOWTABLE_NO
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "LimitMode"
				Select
					Case $_sContent == "0"
						Return $PRTG_LIMITMODE_NO
					Case $_sContent == "1"
						Return $PRTG_LIMITMODE_YES
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "NotifyChanged"
				Select
					Case StringIsSpace($_sContent) Or $_sContent == "0"
						Return 0
					Case Else
						Return $PRTG_NOTIFYCHANGED
				EndSelect

			Case $_sTag = "SpeedSize"
				Select
					Case $_sContent = "One"
						Return $PRTG_SPEEDSIZE_ONE
					Case $_sContent = "Kilo"
						Return $PRTG_SPEEDSIZE_KILO
					Case $_sContent = "Mega"
						Return $PRTG_SPEEDSIZE_MEGA
					Case $_sContent = "Giga"
						Return $PRTG_SPEEDSIZE_GIGA
					Case $_sContent = "Tera"
						Return $PRTG_SPEEDSIZE_TERA
					Case $_sContent = "Byte"
						Return $PRTG_SPEEDSIZE_BYTE
					Case $_sContent = "KiloByte"
						Return $PRTG_SPEEDSIZE_KILOBYTE
					Case $_sContent = "MegaByte"
						Return $PRTG_SPEEDSIZE_MEGABYTE
					Case $_sContent = "GigaByte"
						Return $PRTG_SPEEDSIZE_GIGABYTE
					Case $_sContent = "TeraByte"
						Return $PRTG_SPEEDSIZE_TERABYTE
					Case $_sContent = "Bit"
						Return $PRTG_SPEEDSIZE_BIT
					Case $_sContent = "KiloBit"
						Return $PRTG_SPEEDSIZE_KILOBIT
					Case $_sContent = "MegaBit"
						Return $PRTG_SPEEDSIZE_MEGABIT
					Case $_sContent = "GigaBit"
						Return $PRTG_SPEEDSIZE_GIGABIT
					Case $_sContent = "TeraBit"
						Return $PRTG_SPEEDSIZE_TERABIT
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "SpeedTime"
				Select
					Case $_sContent = "Second"
						Return $PRTG_SPEEDTIME_SECOND
					Case $_sContent = "Minute"
						Return $PRTG_SPEEDTIME_MINUTE
					Case $_sContent = "Hour"
						Return $PRTG_SPEEDTIME_HOUR
					Case $_sContent = "Day"
						Return $PRTG_SPEEDTIME_DAY
					Case Else
						Return 0
				EndSelect

			Case $_sTag = "VolumeSize"
				Select
					Case $_sContent = "One"
						Return $PRTG_VOLUMESIZE_ONE
					Case $_sContent = "Kilo"
						Return $PRTG_VOLUMESIZE_KILO
					Case $_sContent = "Mega"
						Return $PRTG_VOLUMESIZE_MEGA
					Case $_sContent = "Giga"
						Return $PRTG_VOLUMESIZE_GIGA
					Case $_sContent = "Tera"
						Return $PRTG_VOLUMESIZE_TERA
					Case $_sContent = "Byte"
						Return $PRTG_VOLUMESIZE_BYTE
					Case $_sContent = "KiloByte"
						Return $PRTG_VOLUMESIZE_KILOBYTE
					Case $_sContent = "MegaByte"
						Return $PRTG_VOLUMESIZE_MEGABYTE
					Case $_sContent = "GigaByte"
						Return $PRTG_VOLUMESIZE_GIGABYTE
					Case $_sContent = "TeraByte"
						Return $PRTG_VOLUMESIZE_TERABYTE
					Case $_sContent = "Bit"
						Return $PRTG_VOLUMESIZE_BIT
					Case $_sContent = "KiloBit"
						Return $PRTG_VOLUMESIZE_KILOBIT
					Case $_sContent = "MegaBit"
						Return $PRTG_VOLUMESIZE_MEGABIT
					Case $_sContent = "GigaBit"
						Return $PRTG_VOLUMESIZE_GIGABIT
					Case $_sContent = "TeraBit"
						Return $PRTG_VOLUMESIZE_TERABIT
					Case Else
						Return 0
				EndSelect

		EndSelect

		Return SetError(1, 0, 0)	; if we made it here, we had no match

	EndFunc


#EndRegion ### PRTG OPTIONS AND BIT TRANSLATIONS ###


