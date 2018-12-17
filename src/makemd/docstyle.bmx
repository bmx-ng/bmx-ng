
Strict

Import BRL.MaxUtil
Import brl.stringbuilder

Import "bbdoc.bmx"

Import "docnode.bmx"

Global BmxDocDir$=BlitzMaxPath()+"/docs/md"

Global NodeKinds$[]=[ "/","Module","Type", "Interface" ]

Global LeafKinds$[]=[ "Const","Field","Global","Method","Function","Keyword" ]

Global AllKinds$[]=NodeKinds+LeafKinds

Type TDocStyle Extends TBBLinkResolver

	Field generated:String
	Field doc:TDocNode
	Field stack:TList = New TList
	Field children:TMap
	Field docURL$
	Field absDocDir$		'where output doc goes
	Field relRootDir$		'relative path to root doc dir
	Field outputPath:String
	
	'Field stream:TStream
	Field indent:Int = 0
	Field sb:TStringBuilder = New TStringBuilder(16384)
	
	Global commands:TMap=New TMap

	Method NodeIsleaf( node:TDocNode )
		For Local t$=EachIn LeafKinds
			If t=node.kind Return True
		Next
	End Method
	
	Method FindNode:TDocNode( node:TDocNode,id$ )

		If node.id.ToLower()=id Then
			Return node
		End If

		If node.path.Tolower().EndsWith( "/"+id ) Return node

		For Local t:TDocNode=EachIn node.children
			Local p:TDocNode=FindNode( t,id )
			If p Return p
		Next
	End Method
	
	Method NodeURL$( node:TDocNode, forLink:Int = False )
		If node.kind="Topic"
			Return node.path+".md"
		Else If NodeIsLeaf( node )
			Local path:String = node.path.ToLower()

			Return ExtractDir( path )+"/#"+node.protoId
		Else If node.path<>"/"
			If node.kind = "Module" Then
				Return node.path.Replace(".", "_")+".md"
			Else
				If forLink Then
					Return node.path.ToLower()'.Replace(".", "_")+".md"
				Else
					Return node.path.ToLower() + ".md" '.Replace(".", "_")+".md"
				End If
			End If
		Else
			Return "/" + node.id + ".md"
		EndIf
	End Method
	
	Method ResolveLink$( link$ )

		Local id$=link.ToLower().Trim()

		Local node:TDocNode=FindNode( doc,id )
		
		If Not node 
			node=FindNode( TDocNode.ForPath( "/" ),id )
		EndIf
		
		If Not node 
			Print "Error: Unable to resolve link '"+link+"'"
			Return link
		EndIf

		Local url$=nodeURL( node, True )

		'optimize links...
		If url.StartsWith( docURL+"#" )
			url=url[ docURL.length.. ]
		Else If url.StartsWith( doc.path+"/" )

			If doc.kind = "Module" Then
				url = "../.." + url
			Else If doc.kind = "Type" Or doc.kind = "Interface" Then
				url = "../../.." + url
			End If
		Else
			url=relRootDir+url
		EndIf
		Return "[" + link + "](" + url + ")"

	End Method
	
	Method EmitDoc( node:TDocNode)
		
		Print "Building: "+node.id

		generated=""
		doc=node
		children=New TMap
		stack.AddLast(children)
		docURL=NodeURL( doc )
		absDocDir=BmxDocDir+ExtractDir( docURL )

		If doc.kind = "Type" Or doc.kind = "Interface" Then
			relRootDir="../../.."
		Else
			relRootDir="../.."
		End If

		Local p$=ExtractDir( docURL )
		While p<>"/"
			p=ExtractDir( p )
		Wend
		If Not relRootDir relRootDir="."

		CreateDir absDocDir,True
			
		outputPath = BmxDocDir+docURL
		
		If doc.docDir FilteredCopyDir doc.docDir,absDocDir

		Local intro$=absDocDir+"/index.bbdoc"
		If FileType( intro )<>FILETYPE_FILE intro$=absDocDir+"/intro.bbdoc"
		If FileType( intro )=FILETYPE_FILE
			Local t$=LoadText( intro )
			DeleteFile intro ' remove bbdoc file
			If t.find( "commands.html" )<>-1
				Print "Error: Document contains 'commands.html'"
			EndIf
			doc.about=t+doc.about
		EndIf

		For Local t:TDocNode=EachIn doc.children

			Local list:TList=TList( children.ValueForKey( t.kind ) )
			If Not list
				list=New TList
				children.Insert t.kind,list
			EndIf

			list.AddLast t
		Next
		
		EmitHeader
		
		If node.kind = "Module" Then
			For Local t$=EachIn NodeKinds
				EmitLinks t
			Next
		End If
		
		Local leafOrder:String[] = ["Field", "Method", "Function", "Global", "Const", "Keyword"]

		For Local order:String = EachIn leafOrder
			For Local t$=EachIn LeafKinds
				If order = t Then
					EmitDecls node, t
				End If
			Next
		Next

		EmitFooter
		
		
		If node.kind <> "/" Then
			generated=BBToHtml( sb.ToString(),Self )

			SaveText generated,outputPath
		End If

		sb.SetLength(0)

		For Local t$=EachIn NodeKinds
			EmitNodes t
		Next
		
		stack.RemoveLast()
		children = TMap(stack.Last())

	End Method
	
	Method EmitNodes( kind$ )
		Local list:TList=TList( children.ValueForKey( kind ) )
		If Not list Return
		
		For Local t:TDocNode=EachIn list
			EmitDoc t
		Next

	End Method
	
	Method Emit( t$ )
		sb.Append(t).AppendNewLine()
	End Method
	
	Method ChildList:TList( kind$ )
		Return TList( children.ValueForKey( kind ) )
	End Method
	
	Method Underline:String(Text:String, char:String)
		Local under:Short[Text.length]
		For Local i:Int = 0 Until Text.length
			under[i] = Asc(char)
		Next
		Return String.FromShorts(under, Text.length)
	End Method
	
	Method EmitHeader() Abstract
	
	Method EmitFooter() Abstract
	
	Method EmitLinks( kind$ ) Abstract
	
	Method EmitDecls( parent:TDocNode, kind$ ) Abstract
	
End Type

Function FilteredCopyDir:Int( src$,dst$ )

	Function CopyDir_:Int( src$,dst$ )
		If FileType( dst )=FILETYPE_NONE CreateDir dst
		If FileType( dst )<>FILETYPE_DIR Return False
		For Local file$=EachIn LoadDir( src )
			Select FileType( src+"/"+file )
			Case FILETYPE_DIR
				If file <> ".bmx" Then
					If Not CopyDir_( src+"/"+file,dst+"/"+file ) Return False
				End If
			Case FILETYPE_FILE
				Local ext:String = ExtractExt(file).ToLower()
				If ext = "bmx" Or ext = "bbdoc" Then
					If Not CopyFile( src+"/"+file,dst+"/"+file ) Return False
				End If
			End Select
		Next
		Return True
	End Function
	
	FixPath src
	If FileType( src )<>FILETYPE_DIR Return False

	FixPath dst
	
	Return CopyDir_( src,dst )

End Function
