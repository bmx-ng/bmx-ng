
Strict

Import BRL.Map
Import "parse.bmx"

Type TDocNode

	Field id$			'eg: BRL.Audio
	Field path$		'eg: Modules/Audio/Audio"
	Field kind$		'eg: "Module", "Function", "Type" etc
	
'	Field proto$		'eg: Function LoadImage(...)
'	Field protoId:String
'	Field protoExId:String
	Field proto:TProto
	Field bbdoc$		'eg: Load an image (shortdesc?)
	Field returns$	'eg: A new image
	Field about$		'eg: blah etc blah (longdesc?)
	Field params:TList	'eg: [x - the x coord, y - the y coord]
	
	Field docDir$		'eg: ../mod/brl.mod/max2d.mod/doc
	Field examples:String[]	'eg: LoadImage.bmx (path)
	
	Field children:TList=New TList
	Field op:String
	
	Function ForPath:TDocNode( path$ )

		Return TDocNode( _pathMap.ValueForKey( path ) )

	End Function
	
	Function GetDocNodeOrOverloadPath:TDocNode(kind:String, origPath:String, path:String Var, protoId:String, count:Int = 0)
		Local t:TDocNode=TDocNode( _pathMap.ValueForKey( path ) )

		If kind <> "Method" And kind <> "Function" Then
			Return t
		End If
		
		If t And t.proto.protoId <> protoId Then
			count :+ 1
			
			path = origPath + "_" + count
			
			Return GetDocNodeOrOverloadPath(kind, origPath, path, protoId, count)
		End If
		
		Return t
	End Function
	
	Function Create:TDocNode( id$,path$,kind$, proto:String, protoId:String )
	
		Local t:TDocNode = GetDocNodeOrOverloadPath(kind, path, path, protoId)
		
		If t
			If t.kind<>"/" And t.path<>path Throw "ERROR: "+t.kind+" "+kind
			If t.path = path Return t
		Else
			t=New TDocNode
			_pathMap.Insert path,t
		EndIf

		t.id=id
		t.path=path
		t.kind=kind
		t.proto = New TProto(id, proto)
		
		Local q:TDocNode=t
		
		Repeat
			If path="/" Exit
			path=ExtractDir( path )
			Local p:TDocNode=TDocNode( _pathMap.ValueForKey( path ) )
			If p
				p.children.AddLast q
				Exit
			EndIf
			p=New TDocNode
			p.id=StripDir(path)
			p.path=path
			p.kind="/"
			p.children.AddLast q
			_pathMap.Insert path,p
			q=p
		Forever
		
		Return t
	End Function
	
	Method AddExample(examplePath:String)

		examples :+ [StripDir(examplePath)]
		
		' check for extra examples
		Local i:Int
		While True
			i :+ 1
			Local path:String = StripExt(examplePath) + "_" + i + ".bmx"
			If FileType(path) = FILETYPE_FILE Then
				examples :+ [StripDir(path)]
				Continue
			End If
			Exit
		Wend
	End Method
	
	Global _pathMap:TMap=New TMap

End Type

Type TProto

	Field id:String
	Field ret:String
	Field args:String
	Field orig:String
	Field protoId:String
	
	Method New(id:String, proto:String)
		Self.id = id
		orig = proto
		
		BuildProtoId()
		BuildDets()
	End Method

	Method BuildProtoId()

		' function-stripdir-path"
		Local s:String
		Local previousIdentChar:Int = False
		For Local n:Int = EachIn orig.Trim()
			' ignore brackets
			If n = Asc("(") Then
				Continue
			End If
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

		protoId = s.ToLower()
	End Method

	Method BuildDets()

		Local s:String = orig.ToLower()

		If s.startsWith("method") Or s.StartsWith("function")
			Local argsList:String
			Local i:Int = s.Find("(")
			Local argStr:String = s
			If i >= 0 Then
				argStr = s[i+1..]
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
		
			Self.args = argsList
		
		End If

	End Method

	Method GetType:String(s:String)
	
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
	End Method

End Type
