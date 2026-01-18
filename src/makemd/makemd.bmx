'
' Generates Markdown formated docs.
'
'
'
'
Strict

Framework BRL.Basic

Import "docnode.bmx"

Import "mdstyle.bmx"

Global opt_api_dump:String
Global apiDumpStream:TStream

ParseArgs(AppArgs[1..])

Local style:TDocStyle=New TRstStyle

DeleteDir BmxDocDir,True

Local root:TDocNode=TDocNode.Create( "BlitzMax Help","/","/", Null, Null )

CheckConfig()

DocMods

DocBBDocs "/"

style.EmitDoc TDocNode.ForPath( "/" )

Cleanup BmxDocDir

If apiDumpStream Then
	apiDumpStream.Close()
End If

'*****

Function Cleanup( dir$ )
	For Local e$=EachIn LoadDir( dir )
		Local p$=dir+"/"+e
		Select FileType( p )
		Case FILETYPE_DIR
			Cleanup p
		Case FILETYPE_FILE
			If ExtractExt( e )="bbdoc"
				DeleteFile p
			Else If e.ToLower()="commands.html"
				DeleteFile p
			EndIf
		End Select
	Next
End Function

Function DocMods()
	Local shippedMods:String[] = [ ..
	                              "brl.", "pub.", ..
	                              "archive.", "audio.", "collections.","crypto.", ..
	                              "image.", "math.", "maxgui.", ..
	                              "mky.", "net.", "random.", ..
	                              "sdl.", "steam.", "text." ]

	For Local modid$=EachIn EnumModules()
		Local ignoreMod:Int = True

		For Local shippedMod:String = EachIn shippedMods
			If modid.StartsWith(shippedMod) 
				ignoreMod = False
				exit
			EndIf
		Next
		If ignoreMod Then Continue

		Local p$=ModuleSource( modid )
		Try
			docBmxFile p,""
		Catch ex$
			Print "Error:"+ex
		End Try
	Next

End Function

Function DocBBDocs( docPath$ )

	Local p$=BmxDocDir+docPath
	
	For Local e$=EachIn LoadDir( p )

		Local q$=p+"/"+e

		Select FileType( q )
		Case FILETYPE_FILE
			Select ExtractExt( e )
			Case "bbdoc"
				Local id$=StripExt( e )
				If id="index" Or id="intro" Continue
				
				Local path$=(docPath+"/"+id).Replace( "//","/" )
				Local node:TDocNode=TDocNode.Create( id,path,"/", Null, Null )

				node.about=LoadText( q )
			End Select
		Case FILETYPE_DIR
			DocBBDocs docPath+"/"+e
		End Select
	Next
	
End Function

Function docBmxFile( filePath$,docPath$ )

	If FileType( filePath )<>FILETYPE_FILE
		Print "Error: Unable to open '"+filePath+"'"
		Return
	EndIf

	Local docDir$=ExtractDir( filePath )+"/doc"
	If FileType( docDir )<>FILETYPE_DIR docDir=""

	Local inrem,typePath$,section$
	
	Local bbdoc$,returns$,about$,keyword$,params:TList
	
	Local Text$=LoadText( filepath )
	
	Local lineNumber:Int
	For Local line$=EachIn Text.Split( "~n" )
		lineNumber :+ 1
		line=line.Trim()
		Local tline$=line.ToLower()
		
		Local i
		Local id$=ParseIdent( tline,i )
		
		If id="end" id:+ParseIdent( tline,i )
		
		If i<tline.length And tline[i]=Asc(":")
			id:+":"
			i:+1
		EndIf
		
		If inrem
		
			If id="endrem"
			
				inrem=False
				
			Else If id="bbdoc:"
			
				bbdoc=line[i..].Trim()
				keyword=""
				returns=""
				about=""
				params=Null
				section="bbdoc"

			Else If bbdoc 
			
				Select id
				Case "keyword:"
					keyword=line[i..].Trim()
					section="keyword"
				Case "returns:"
					returns=line[i..].Trim()+"~n"
					section="returns"
				Case "about:"
					about=line[i..].Trim()+"~n"
					section="about"
				Case "param:"
					If Not params params=New TList
					params.AddLast line[6..].Trim()
					section="param"
				Default
					Select section
					Case "about"
						about:+line+"~n"
					Case "returns"
						returns:+" "+line
					Case "param"
						params.AddLast String( params.RemoveLast() )+" "+line
					Default
						'remaining sections 1 line only...
						If line Print "Error: Illegal bbdoc section in '"+filePath+"' on line " + lineNumber
					End Select
				End Select
			
			EndIf
		
		Else If id="rem"
		
			bbdoc=""
			inrem=True
			
		Else If id="endtype" Or id="endinterface" Or id="endstruct" Or id="endenum"

			If typePath
				docPath=typePath
				typePath=""
			EndIf
			
		Else If id="import" Or id="include"
		
			Local p$=ExtractDir( filePath )+"/"+ParseString( line,i )
			
			If ExtractExt( p ).ToLower()="bmx"
				docBmxFile p,docPath
			EndIf
		
		Else If bbdoc
		
			Local kind$,proto$
			Local op:String
			
			If keyword
				id=keyword
				kind="Keyword"
				If id.StartsWith( "~q" ) And id.EndsWith( "~q" )
					id=id[1..id.length-1]
				EndIf
				proto=id
			Else If id
				For Local t$=EachIn AllKinds
					If id<>t.ToLower() Continue
					kind=t
					proto=line
					id=ParseIdent( line,i )

					If id.ToLower() = "operator" Then
						op = ParseOperator(line, i)
						id :+ op
					End If

					Exit
				Next
			EndIf
			
			If kind

				Local path$

				Select kind
				Case "Type", "Interface", "Struct", "Enum"
					If Not docPath Throw "No doc path for id=" + id
					If typePath Throw "Type path already set"
					typePath=docPath
					docPath:+"/"+id
					path=docPath
				Case "Module"
					If docPath Throw "Doc path already set"
					If bbdoc.FindLast( "/" )=-1
						bbdoc="Other/"+bbdoc
					EndIf
					'docPath="/Modules/"+bbdoc
					Local idLower:String = id.ToLower()
					docPath = "/" + idLower[..idLower.find(".")] + "/" + idLower
					path=docPath
					Local i=bbdoc.FindLast( "/" )
					bbdoc=bbdoc[i+1..]
				Default
					If Not docPath Throw "No doc path for kind=" + kind + " and id=" + id
					path=docPath+"/"+id
				End Select
				
				Local i=proto.Find( ")=" )
				If i<>-1 
					proto=proto[..i+1]
					If id.StartsWith( "Sort" ) proto:+" )"	'lazy!!!!!
				EndIf
				i=proto.Find( "=New" )
				If i<>-1
					proto=proto[..i]
				EndIf
				
				Local node:TDocNode=TDocNode.Create( id,path,kind, proto, BuildProtoId(proto) )
				node.bbdoc=bbdoc
				node.returns=returns
				node.about=about
				node.params=params
				node.op = op

				If kind="Module" node.docDir=docDir		

				If docDir Then
					' try type method/function - type_method.bmx
					Local m:String = StripDir(path)
					Local t:String = StripDir(ExtractDir(path))
					
					Local a:String = node.proto.args

					If apiDumpStream Then
						If t.Find(".") = -1 And m.Find(".") = -1 Then
							If a Then
								apiDumpStream.WriteLine(t + "|" + m + "|" + (t + "_" + m + "_" + a + ".bmx").ToLower() )
							End If
							apiDumpStream.WriteLine(t + "|" + m + "|" + (t + "_" + m + ".bmx").ToLower() )
						End If
					End If

					Local tmpExampleFilePath:String = CasedFileName(docDir+"/" + t + "_" + m + "_" + a + ".bmx")
					If FileType(tmpExampleFilePath) = FILETYPE_FILE Then
						node.AddExample(tmpExampleFilePath)
					Else
						tmpExampleFilePath = CasedFileName(docDir+"/" + t + "_" + m +".bmx")
						If FileType(tmpExampleFilePath) = FILETYPE_FILE Then
							node.AddExample(tmpExampleFilePath)
						Else
							tmpExampleFilePath = CasedFileName(docDir+"/"+id+".bmx")

							If FileType( tmpExampleFilePath )=FILETYPE_FILE
								node.AddExample(tmpExampleFilePath)
							End If
						End If
					End If
				EndIf
				
			EndIf
			
			bbdoc=""

		EndIf
	Next
	
End Function

Function BuildProtoId:String(proto:String, ignoreOtherChars:Int = True)

	' function-stripdir-path"
	Local s:String
	Local previousIdentChar:Int = False
	For Local n:Int = EachIn proto.Trim()
		If IsProtoIdentChar(n) Then
			s :+ Chr(n)
			previousIdentChar = True
		Else
			If ignoreOtherChars And n <> Asc(" ") Then
				Continue
			End If
			
			If previousIdentChar Then
				s :+ "-"
			End If
			previousIdentChar = False
		End If
	Next
	Return s.ToLower()
End Function

Function CheckConfig()

	If opt_api_dump Then
		apiDumpStream = WriteFile(opt_api_dump)
		
		If Not apiDumpStream Then
			Print "Unable to create api dump file : " + opt_api_dump
		End If
	
	End If
	
End Function

Function ParseArgs(args:String[])

	Local count:Int

	While count < args.length
	
		Local arg:String = args[count]

		If arg[..1] <> "-" Then
			Exit
		End If
		
		Select arg[1..]
			Case "d"
				count :+ 1
				If count = args.length Then
					Throw "Command line error - Missing output file arg for '-d'"
				End If
				opt_api_dump = args[count]
		End Select
		
		count :+ 1
	Wend
	
End Function
