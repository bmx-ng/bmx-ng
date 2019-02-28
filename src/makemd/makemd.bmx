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

Local root:TDocNode=TDocNode.Create( "BlitzMax Help","/","/", Null )

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

	For Local modid$=EachIn EnumModules()

		If Not modid.StartsWith( "brl." ) And Not modid.StartsWith( "pub." ) And Not modid.StartsWith("maxgui.") And Not modid.StartsWith("sdl.") Continue

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
				Local node:TDocNode=TDocNode.Create( id,path,"/", Null )

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
	
	For Local line$=EachIn Text.Split( "~n" )

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
						If line Print "Error: Illegal bbdoc section in '"+filePath+"'"
					End Select
				End Select
			
			EndIf
		
		Else If id="rem"
		
			bbdoc=""
			inrem=True
			
		Else If id="endtype" Or id="endinterface" Or id="endstruct"

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
				Case "Type", "Interface", "Struct"
					If Not docPath Throw "No doc path"
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
					If Not docPath Throw "No doc path"
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
				
				Local node:TDocNode=TDocNode.Create( id,path,kind, BuildProtoId(proto) )

				node.proto=proto
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
					
					Local a:String = ExtractArgs(node.protoId)
					
					If node.protoId And apiDumpStream Then
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

Function ExtractArgs:String(proto:String)
	Local s:String[] = proto.Split("+")
	If s.length = 2 Then
		Return s[1]
	End If
	Return ""
End Function

Function BuildProtoId:String(proto:String)
	proto = proto.ToLower()
	
	' function-stripdir-path"
	Local s:String
	Local previousIdentChar:Int = False
	For Local n:Int = EachIn proto.Trim()
		If IsProtoIdentChar(n) Then
			s :+ Chr(n)
			previousIdentChar = True
		Else
			If previousIdentChar Then
				s :+ "-"
			End If
			previousIdentChar = False
		End If
	Next
	If s.EndsWith("-") Then
		s = s[..s.Length-1]
	End If
	
	If s.startsWith("method") Or s.StartsWith("function")
		Local argsList:String
		Local i:Int = proto.Find("(")
		Local argStr:String = proto
		If i >= 0 Then
			argStr = proto[i+1..]
		End If

		Local args:String[] = argStr.Split(",")
		For Local arg:String = EachIn args
			Local p:String[] = arg.split("=")
			Local a:String = p[0].Trim()
			If a = ")" Then
				Exit
			End If
			p = a.Split(":")
			Local ty:String
			If p.length = 2 Then
				ty = GetType(p[1].Split(" ")[0].Trim())
			Else
				ty = "i"
			End If
			argsList :+ ty
		Next
		
		Local count:Int
		For i:Int = 0 Until s.length
			If s[i] = Asc("-")
				count :+ 1
				If count = 2 Then
					s = s[..i] + "+" + argsList
				End If
			End If
		Next
	End If
	Return s
End Function

Function GetType:String(s:String)

	If s.EndsWith(")") Then
		s = s[..s.length-1]
	End If

	Local ty:String = s
	s = s.ToLower()
	
	Select s
		Case "byte", "short", "int", "long", "uint", "float", "double"
			ty = s[0..1]
		Case "ulong"
			ty = "ul"
		Case "size_t"
			ty = "t"
		Case "string", "$"
			ty = "r"
	End Select
	Return ty
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
