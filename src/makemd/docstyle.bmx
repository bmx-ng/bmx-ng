
Strict

Import BRL.MaxUtil
Import brl.stringbuilder

Import "bbdoc.bmx"

Import "docnode.bmx"

Const DOC_API:Int = 1

Global BmxDocDir$=BlitzMaxPath()+"/docs/md"

Global NodeKinds$[]=[ "/","Module","Type", "Interface", "Struct", "Enum" ]

Global LeafKinds$[]=[ "Const","Field","Global","Method","Function","Keyword" ]

Global AllKinds$[]=NodeKinds+LeafKinds

Type TDocBlocks

	Field blocks:TObjectList = New TObjectList
	
	Field currentBlock:TBlock

	Method Emit(txt:String)
		If Not currentBlock Or TSourceBlock(currentBlock) Then
			currentBlock = New TBlock
			blocks.AddLast(currentBlock)
		End If
		
		currentBlock.sb.Append(txt)
	End Method
	
	Method EmitSource(txt:String)
		If Not TSourceBlock(currentBlock) Then
			currentBlock = New TSourceBlock
			blocks.AddLast(currentBlock)
		End If

		currentBlock.sb.Append(txt)
	End Method
	
	Method Clear()
		blocks.Clear()
		currentBlock = Null
	End Method
	
	Method Generate:String(doc:TBBLinkResolver)
		Local sb:TStringBuilder = New TStringBuilder
		
		For Local block:TBlock = EachIn blocks
			If Not TSourceBlock(block) Then
				sb.Append(BBToHtml( block.sb.ToString(),doc ))
			Else
				sb.Append(block.sb)
			End If
		Next
		
		Return sb.ToString()
	End Method
End Type

Type TBlock

	Field sb:TStringBuilder = New TStringBuilder(4096)

End Type

Type TSourceBlock Extends TBlock

End Type

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
	Field docBlocks:TDocBlocks = New TDocBlocks
	
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

			Return ExtractDir( path )+"/#"+node.proto.protoId
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
				If DOC_API = 1 Then
					url = "../.." + url
				Else
					url = ".." + url
				End If
			Else If doc.kind = "Type" Or doc.kind = "Interface" Or doc.kind = "Struct" Or doc.kind = "Enum" Then
				url = "../../.." + url
			End If
		Else
			If doc.kind = "Module" And node.kind = "Module" Then
				url=".." + url
			Else
				url=relRootDir+url
			End If
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

		If doc.kind = "Type" Or doc.kind = "Interface" Or doc.kind = "Struct" Or doc.kind = "Enum" Then
			If DOC_API = 1 Then
				relRootDir="../../.."
			Else
				relRootDir="../.."
			End If
		Else
			If DOC_API = 1 Then
				relRootDir="../.."
			Else
				relRootDir=".."
			End If
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
		Local categoryOrder:String[] = ["Constructor", "Operator", "-", "Destructor"]

		For Local order:String = EachIn leafOrder
			For Local t$=EachIn LeafKinds
				If order = t Then
					If order = "Method" Then
						For Local category:String = EachIn categoryOrder
							EmitDecls node, t, category
						Next
					Else
						EmitDecls node, t
					End If
				End If
			Next
		Next

		EmitFooter
		
		
		If node.kind <> "/" Then
			generated = docBlocks.Generate(Self)

			SaveText generated,outputPath,ETextStreamFormat.UTF8,False
		End If

		docBlocks.Clear()

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
		docBlocks.Emit(t)
		docBlocks.Emit("~n")
	End Method

	Method EmitSource( t$ )
		docBlocks.EmitSource(t)
		docBlocks.EmitSource("~n")
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
	
	Method EmitDecls( parent:TDocNode, kind$, category:String = Null ) Abstract
	
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
