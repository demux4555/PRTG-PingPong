#include-once

; NOTE: 	2016.10.01 		Added ArgCheck()
; Based on: https://www.autoitscript.com/forum/topic/123438-command-line-argument-management/

Global $CmdLine_Cache[1][2] = [[0, False]]

; #FUNCTION# ====================================================================================================================
; Name ..........: CmdLine
; Description ...: Returns the value of the command line parameter.
; Syntax ........: CmdLine( [ $sParam ] )
; Parameters ....: $sParam          - [optional] A string specifying the command line parameter to retrieve. Default is a blank
;                                     string, which is the parameter that does not have a named flag first.
; Return values .: Success          - If the parameter has a value, then that is returned. If not then True is.
;                  Failure          - False. Usually means that the parameter wasn't in the command line.
; Author(s) .....: Matt Diesel (Mat)
; Modified ......:
; Remarks .......:
; Related .......: _CmdLine_Parse
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================
Func CmdLine($sParam = "")
    If $CmdLine_Cache[0][0] = 0 And $CmdLine[0] > 0 Then _CmdLine_Parse()

    If $sParam = "" Then
        Return $CmdLine_Cache[0][1]
    Else
        For $i = 1 To UBound($CmdLine_Cache) - 1
            If $CmdLine_Cache[$i][0] = $sParam Then Return $CmdLine_Cache[$i][1]
        Next
        Return False
    EndIf
EndFunc   ;==>CmdLine


; #FUNCTION# ====================================================================================================================
; Name ..........: _CmdLine_Parse
; Description ...:
; Syntax ........: _CmdLine_Parse( [ $sPrefix [, $asAllowed [, $sOnErrFunc ]]] )
; Parameters ....: $sPrefix         - [optional] The prefix for command line arguments. Default is '--'. It is recommended that
;                                     it is one of the following standards (although it could be anything):
;                                   |GNU     - uses '--' to start arguments. <a href="http://www.gnu.org/prep/standards/
;                                              html_node/Command_002dLine-Interfaces.html">Page</a>. '--' on it's own sets the
;                                              unnamed argument but always uses the next parameter, even if prefixed by '--'.
;                                              E.g. '-- --file' will mean CmdLine() = '--file'.
;                                   |MS      - uses '-'. Arguments with values are seperated by a colon: ':'. <a
;                                              href="http://technet.microsoft.com/en-us/library/ee156811.aspx">Page</a>
;                                   |Slashes - Not sure where it's a standard, but using either backslash ( '\' ) or slash
;                                              ( '/' ) is fairly common. AutoIt uses it :) Just make sure the user knows which
;                                              one it is.
;                  $asAllowed       - [optional] A zero based array of possible command line arguments that can be used. When an
;                                     argument is found that does not match any of the values in the array, $sOnErrFunc is called
;                                     with the first parameter being "Unrecognized parameter: PARAM_NAME".
;                  $sOnErrFunc      - [optional] The function to call if an error occurs.
; Return values .: None
; Author(s) .....: Matt Diesel (Mat)
; Modified ......:
; Remarks .......:
; Related .......: This function must be called (rather than used in #OnAutoItStartRegister), as it uses a global array.
; Link ..........:
; Example .......: Yes
; ===============================================================================================================================
Func _CmdLine_Parse($sPrefix = "--", $asAllowed = 0, $sOnErrFunc = "")
    If IsString($asAllowed) Then $asAllowed = StringSplit($asAllowed, "|", 3)

    For $i = 1 To $CmdLine[0]
        If $CmdLine[$i] = "--" Then
            If $i <> $CmdLine[0] Then
                $CmdLine_Cache[0][1] = $CmdLine[$i + 1]
                $i += 1
            Else
                $CmdLine_Cache[0][1] = True
            EndIf
        ElseIf StringLeft($CmdLine[$i], StringLen($sPrefix)) = $sPrefix Then
            $CmdLine_Cache[0][0] = UBound($CmdLine_Cache)
            ReDim $CmdLine_Cache[$CmdLine_Cache[0][0] + 1][2]

            If StringInStr($CmdLine[$i], "=") Then
                $CmdLine_Cache[$CmdLine_Cache[0][0]][0] = StringLeft($CmdLine[$i], StringInStr($CmdLine[$i], "=", 2) - 1)
                $CmdLine_Cache[$CmdLine_Cache[0][0]][0] = StringTrimLeft($CmdLine_Cache[$CmdLine_Cache[0][0]][0], StringLen($sPrefix))
                $CmdLine_Cache[$CmdLine_Cache[0][0]][1] = StringTrimLeft($CmdLine[$i], StringInStr($CmdLine[$i], "=", 2))
            ElseIf StringInStr($CmdLine[$i], ":") Then
                $CmdLine_Cache[$CmdLine_Cache[0][0]][0] = StringLeft($CmdLine[$i], StringInStr($CmdLine[$i], ":", 2) - 1)
                $CmdLine_Cache[$CmdLine_Cache[0][0]][0] = StringTrimLeft($CmdLine_Cache[$CmdLine_Cache[0][0]][0], StringLen($sPrefix))
                $CmdLine_Cache[$CmdLine_Cache[0][0]][1] = StringTrimLeft($CmdLine[$i], StringInStr($CmdLine[$i], ":", 2))
            Else
                $CmdLine_Cache[$CmdLine_Cache[0][0]][0] = StringTrimLeft($CmdLine[$i], StringLen($sPrefix))
                If ($i <> $CmdLine[0]) And (StringLeft($CmdLine[$i + 1], StringLen($sPrefix)) <> $sPrefix) Then
                    $CmdLine_Cache[$CmdLine_Cache[0][0]][1] = $CmdLine[$i + 1]
                    $i += 1
                Else
                    $CmdLine_Cache[$CmdLine_Cache[0][0]][1] = True
                EndIf
            EndIf

            If $asAllowed <> 0 Then
                For $n = 0 To UBound($asAllowed) - 1
                    If $CmdLine_Cache[$CmdLine_Cache[0][0]][0] = $asAllowed[$n] Then ContinueLoop 2
                Next

                If $sOnErrFunc <> "" Then Call($sOnErrFunc, "Unrecognized parameter: " & $CmdLine_Cache[$CmdLine_Cache[0][0]][0])
            EndIf
        Else
            If Not $CmdLine_Cache[0][1] Then
                $CmdLine_Cache[0][1] = $CmdLine[$i]
            Else
                If $sOnErrFunc <> "" Then Call($sOnErrFunc, "Unrecognized parameter: " & $CmdLine[$i])
            EndIf
        EndIf
    Next
EndFunc   ;==>_CmdLine_Parse


; #FUNCTION# ====================================================================================================================
; Name ..........: ArgCheck v1.1
; Description ...: Check command line argument, and return either a default/fallback value or the actual value of the command
;                  line argument. Works with both  -Options:"text"  and switches  -D
; Syntax ........: ArgCheck($_CmdValue, $_DefValue[, $_IsBool])
; Parameters ....: $_CmdValue           - CmdLine() argument name. A CmdLine("X") return value.
;                  $_DefValue           - Default/fallback value of the argument. The default value to return if CmdLine() finds no argument.
;                  $_IsBool             - [optional] Argument is a switch (i.e. -D). Default is 0. Will return either False or True.
; Return value ..: $_DefValue if argument is not used on command line, otherwise it returns CmdLine("X") value.
; Author ........: demux4555
; Modified ......: 2016.10.01
; Remarks .......:
; Requires ......: CmdLine.au3 UDF (part of)
; Examples ......: Global $_D = ArgCheck( CmdLine("d"), False, 1 )		; use -D to enable debug. Disabled by default.
;                  Global $_H = ArgCheck( CmdLine("h"), "127.0.0.1" )	; use -H:192.168.0.1 to set host, defaults to 127.0.0.1
; ===============================================================================================================================
Func ArgCheck($_CmdValue, $_DefValue, $_IsBool = 0)				; if $_IsBool = 1 it means the argument is a switch i.e. 	 -D

	If ($_IsBool == 0) Or ($_IsBool == False) Or ($_IsBool == Default) Or StringIsSpace($_IsBool) Then
		If Not IsBool($_CmdValue) Then
			Return $_CmdValue
		Else
			Return $_DefValue
		EndIf
	ElseIf ($_IsBool == 1) Or ($_IsBool == True) Then
		If IsBool($_CmdValue) Then
			Return $_CmdValue
		Else
			Return $_DefValue
		EndIf
	EndIf

EndFunc

