' 
' Copyright 2018 Bruce A Henderson
' 
' Licensed under the Apache License, Version 2.0 (the "License"); you may not
' use this file except in compliance with the License. You may obtain a copy of
' the License at
' 
'     http://www.apache.org/licenses/LICENSE-2.0
' 
' Unless required by applicable law or agreed to in writing, software
' distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
' WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
' License for the specific language governing permissions and limitations under
' the License.
' 

'
' bootstrap starter
'
' 
'
SuperStrict

Framework brl.standardio
Import brl.filesystem
Import brl.stringbuilder
Import bah.libarchive
Import bah.libcurl
Import bah.format

Const APP_TITLE:String = "BlitzMax bootstrap"
Const VERSION:String = "1.0.0"
Const BLOCK_SIZE:Int = 65536

Print APP_TITLE + " v" + VERSION
Print ""

Local options:TOptions = New TOptions()
options.ParseArgs(AppArgs[1..])

Local config:TConfig = TConfig.Load(options)

If options.verbose Then
	Print options.ToString()
End If

config.ProcessDownloads()

End

Type TOptions

	Field target:String
	Field config:String
	Field force:Int
	Field verbose:Int
	
	Field canShowProgress:Int

	Method New()
		canShowProgress = _isatty(0)
		config = "boot_files.txt"
		InitTarget()		
	End Method
	
	Method ParseArgs(args:String[])
		Local i:Int
		For i = 0 Until args.length
			Local arg:String = args[i]
			If arg[..1] <> "-" Then
				Exit
			End If
			Select arg[1..]
				Case "t"
					i:+1
					CheckArg(i, args.length, "t")
					target = args[i].ToLower()
				Case "c"
					i:+1
					CheckArg(i, args.length, "c")
					config = args[i].ToLower()
				Case "f"
					force = True
				Case "v"
					verbose = True
				Case "h"
					ShowUsage()
					End
			End Select
		Next
	End Method
	
	Method ShowUsage()
		Print "usage: bootstrap [options]"
		Print " -c <filename> Specific configuration to load"
		Print " -f            Force install if assets already exist"
		Print " -h            Help"
		Print " -t            Set bootstrap target"
		Print "               Default : " + target
		Print " -v            Verbose output"
		Print ""
	End Method

	Method CheckArg(index:Int, length:Int, option:String)
		If index = length Then
			Throw "Missing arg for '-" + option + "'"
		End If
	End Method
	
	Method ToString:String()
		Local sb:TStringBuilder = New TStringBuilder()
		sb.Append("Target = ").Append(target).AppendNewLine()
		sb.Append("Force  = ").AppendInt(force).AppendNewLine()
		sb.Append("TTY    = ").AppendInt(canShowProgress).AppendNewLine()
		Return sb.ToString()
	End Method
	
	Method InitTarget()
?win32
		target = "win32"
?linux
		target = "linux"
?macos
		target = "macos"
?x86
		target :+ "x86"
?x64
		target :+ "x64"
?arm
		target :+ "arm"
?arm64
		target :+ "arm64"
?
	End Method
	
	Method MatchesTarget:Int(otherTarget:String)
		Return target = otherTarget Or otherTarget = "any" Or target.StartsWith(otherTarget)			
	End Method
	
End Type

Type TConfig

	Field downloads:TList = New TList
	Field options:TOptions
	
	Function Load:TConfig(options:TOptions)
		Local this:TConfig = New TConfig()
		this.options = options
		
		Local config:String = LoadText(options.config)
		For Local line:String = EachIn config.Split("~n")
			line = line.Trim()
			If line Then
				this.downloads.AddLast(TDownLoad.Create(line))
			End If
		Next
		
		Return this
	End Function

	Method ProcessDownloads()
		For Local download:TDownload = EachIn downloads
			If download.Download(options) Then
				download.Unpack(options)
			End If
		Next
	End Method
	
End Type

Type TDownload

	Field target:String
	Field filename:String
	Field uri:String
	Field extractFolder:String
	Field finalFolder:String

	Function Create:TDownload(line:String)
		Local download:TDownload = New TDownload
		Local fields:String[] = line.Split("~t")
		If fields.length < 3 Then
			Return Null
		End If
		
		download.target = fields[0]
		download.filename = fields[1]
		download.uri = fields[2]
		
		If fields.length >= 5 Then
			download.extractFolder = fields[3]
			download.finalFolder = fields[4]
		End If
		
		Return download
	End Function

	Method Download:Int(options:TOptions)
		Clear()
		
		If target And (Not options.MatchesTarget(target)) Then
			Return False
		End If
		
		If FileType(finalFolder) = FILETYPE_DIR And Not options.force Then
			Print "Folder '" + finalFolder + "' already exists. Skipping..."
			Return True
		End If
		
		If FileType(filename) And Not options.force Then
			Print "File '" + filename + "' already exists. Skipping download..."
			Return True
		End If
		
		Print "Downloading '" + filename + "'"
		Local stream:TStream = WriteStream(filename)

		Local curl:TCurlEasy = TCurlEasy.Create()
		
		curl.setOptInt(CURLOPT_FOLLOWLOCATION, 1)
		curl.setOptInt(CURLOPT_SSL_VERIFYPEER, False)
		
		Local progress:TProgress
		
		If options.canShowProgress Then
			progress = New TProgress
			curl.setProgressCallback(ShowProgress, progress)
		End If
		
		curl.setOptString(CURLOPT_URL, uri)
		
		' redirect data to stream
		curl.setWriteStream(stream)
		
		Local result:Int = curl.perform()

		If result Then
			Throw "Error downloading file : " + CurlError(result)
		End If
		
		curl.cleanup()
		
		stream.Close()
		
		Return True
	End Method
	
	Method Unpack(options:TOptions)
		Clear()

		If FileType(finalFolder) = FILETYPE_DIR And Not options.force Then
			Return
		End If
		
		' if the folder exists, then we are here by force. Attempt to delete it:
		If FileType(finalFolder) = FILETYPE_DIR Then
			If options.verbose Then
				Print "Removing folder '" + finalFolder + "'"
			End If
			If Not DeleteDir(finalFolder, True)
				Throw "Cannot delete folder '" + finalFolder + "'"
			End If
		End If
	
		Local unpacker:TUnPacker = New TUnPacker(Self)
		unpacker.Unpack(options)
		
		If Not FileType(extractFolder) Then
			Throw "Cannot find unpacked folder '" + extractFolder + "'"
		End If
		
		If FileType(extractFolder) = FILETYPE_DIR Then
			If options.verbose Then
				Print "Renaming '" + extractFolder + "'"
			End If
			If Not RenameFile(extractFolder, finalFolder) Then
				Throw "Unable to rename folder '" + extractFolder + "' to '" + finalFolder + "'"
			End If
		End If
		
	End Method

	Function ShowProgress:Int(data:Object, dltotal:Long, dlnow:Long, ultotal:Long, ulnow:Long)
		Local progress:TProgress = TProgress(data)
		progress.ShowProgress(dltotal, dlnow)
	End Function
	
End Type

Type TUnPacker

	Field download:TDownload
	
	Field archive:TReadArchive
	Field entry:TArchiveEntry

	Method New(download:TDownload)
		Self.download = download
		
		entry = New TArchiveEntry.Create()
	End Method

	Method UnPack(options:TOptions)
		Clear()
		
		Print "Unpacking '" + download.filename + "'"

		Local total:Int = EntryCount()
		
		Open()
		
		Local progress:TProgress
		
		If options.canShowProgress Then
			progress = New TProgress
		End If
		
		Local count:Int
		
		While archive.ReadNextHeader(entry) = ARCHIVE_OK
			
			Local path:String = entry.Pathname()
			Local dir:String = ExtractDir(path)
			
			CreateDir(dir, True)
			
			If Not path.EndsWith("/") Then			
				Local stream:TStream = WriteStream(path)
				
				CopyStream(archive.DataStream(), stream, BLOCK_SIZE)
				
				stream.Close()
			End If
			
			count :+ 1

			If progress Then
				progress.ShowProgress(total, count)
			End If
		Wend

		archive.Free()

		If options.canShowProgress Then
			Clear()
		End If

	End Method
	
	Method Open()
		archive = New TReadArchive.Create()

		archive.SupportFilterAll()
		archive.SupportFormatAll()

		Local result:Int = archive.OpenFilename(download.filename, BLOCK_SIZE)
		
		If result <> ARCHIVE_OK Then
			Throw "Error opening " + download.filename
		End If
	End Method
	
	Method EntryCount:Int()
		Local count:Int
		
		Open()

		While archive.ReadNextHeader(entry) = ARCHIVE_OK
			archive.DataSkip()
			count :+ 1
		Wend

		archive.Free()

		Return count
	End Method

End Type


Type TProgress

	Const full:String  = "                                                                     "
	Const space:String = "                                                          "
	Const bar:String   = "##########################################################"
	
	Field length:Int
	Field progress:Int
	
	Field spin:Int
	Field spinText:String = "\|/-"
	
	Field lastUpdate:Int
	Field startTime:Int
	
	Global formatter:TFormatter = TFormatter.Create(" %02d:%02d:%02d")
	
	Method New()
		length = bar.length
		Clear()
		Put "~r[" + space + "] --:--:--~r"
		
		startTime = MilliSecs()
	End Method

	Method ShowProgress(dltotal:Long, dlnow:Long)
		Local sofar:Float = Float(dlnow) / dltotal
		Local count:Int = length * sofar
		
		Local now:Int = MilliSecs()
		
		If dltotal <> 0 Then

			Local timeTaken:Int = now - startTime
			Local timeLeft:Int = 0
			If dlnow > 0 Then
				timeLeft = (timeTaken / Double(dlnow)) * (dltotal - dlnow)
			Else
				timeLeft = 9999999
			End If

			If progress <> count Or now > lastUpdate + 1000 Then
				Put "~r["
				Local sofar:Float = Float(dlnow) / dltotal
				
				Local s:String = bar[..length * sofar]
				s :+ space[..length - (length * sofar)]
				s :+ "    "
				Put s[..length]
				Put "]  " + FormatTime(timeLeft / 1000) + "~r"
				
				progress = count
				lastUpdate = now
			End If
		Else
			' spinner
						
			If now > lastUpdate + 500 Then
				Put "~r[                          " + spinText[spin..spin+1] + "~r"

				spin :+ 1
				If spin = spinText.Length Then
					spin = 0
				End If
				
				lastUpdate = now
			End If

		End If
	End Method
	
	Method FormatTime:String(time:Int)
		Local seconds:Int = time Mod 60
		Local minutes:Int = (time / 60) Mod 60
		Local hours:Int = time / 3600
		
		formatter.Clear()
		
		If hours > 99 Then
			formatter.IntArg(99).IntArg(59).IntArg(59)
		Else
			formatter.IntArg(hours).IntArg(minutes).IntArg(seconds)
		End If
		
		Return formatter.format()
	End Method
	
End Type

Function Put( str$="" )
	StandardIOStream.WriteString str
	StandardIOStream.Flush
End Function

Function Clear()
	Put "~r  " + TProgress.full + "~r"
End Function

Extern
	Function _isatty:Int(fd:Int)
End Extern

