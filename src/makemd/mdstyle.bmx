
Strict

Import "docstyle.bmx"

Type TRstStyle Extends TDocStyle

	Method EmitHeader()


		If doc.kind = "/" Return

		If doc.kind = "Module" Or doc.kind = "Type" Or doc.kind = "Interface" Then
			Emit "---"
			Emit "id: " + doc.id.ToLower() 
			Emit "title: " + doc.id
			Emit "sidebar_label: " + doc.id
			Emit "---"
			Emit ""
		End If
		
		Local s:String
		
		If doc.kind <> "Module" And doc.kind <> "Type" And doc.kind <> "Interface" Then
			Emit s + doc.id
		End If

		If (doc.kind = "Type" Or doc.kind = "Interface") And doc.bbdoc Then
			Emit doc.bbdoc
			Emit ""
		EndIf
		
		Emit ""

		If doc.about Then
			Emit doc.about
			Emit ""
		End If
		
		If doc.kind = "Type" Or doc.kind = "Interface" Then
			EmitExample(doc)
		End If
		
	End Method
	
	Method EmitFooter()
	
		If doc.kind = "/" Return

	End Method
	
	Method EmitLinks( kind$ )
		Local list:TList=ChildList( kind )
		If Not list Return
		
		'emit anchor: _Const, _Function etc...
		
		If kind="/"
		
			Emit "<table class=doc cellspacing=3>"
			
			For Local t:TDocNode=EachIn list
			
				Emit "<tr><td class=docleft width=1%> #{"+t.id+"}</td></tr>"
	
			Next
	
			Emit "</table>"
		
		Else
		
			Emit "## "+kind+"s"
		
			Emit "| " + kind + " | Description |"
			Emit "|---|---|"
			
			For Local t:TDocNode=EachIn list
				Emit "| #"+t.id+" | " +t.bbdoc+" |"
			Next
	
			Emit ""
		EndIf
	End Method
	
	Method EmitDecls( parent:TDocNode, kind$ )
		Local list:TList=ChildList( kind )
		If Not list Return

		Emit "## " + kind + "s"

		Emit ""
		
		For Local t:TDocNode=EachIn list

			Local s:String
			
			Emit "### `" + t.proto + "`"
			Emit ""
			
			If t.bbdoc
				Emit t.bbdoc
				Emit ""
			EndIf

			If t.about
				For Local line:String = EachIn t.about.Split("~n")
					Emit line
				Next
				Emit ""
			EndIf
 
			If t.returns
				Emit "#### Returns"

				Emit t.returns
				Emit ""
			EndIf
			
			'indent :- 1

			EmitExample(t)
			Rem
			If t.example 
				Emit "#### Example"
				Emit "```blitzmax"

				Local p:String = t.example.ToLower()

				Local path:String = absDocDir+"/"+p
		
				If Not FileType(path) Then
					' try one level up...
					path = ExtractDir(absDocDir) + "/"+p
				End If

				Local code$=LoadText(path).Trim()
				For Local line:String = EachIn code.Split("~n")
					Emit line
				Next
				Emit "```"

			EndIf
			End Rem

			Emit "<br/>"

			Emit ""
			
		Next
	End Method
	
	Method EmitExample(t:TDocNode)
		If t.example 
			Emit "#### Example"
			Emit "```blitzmax"

			Local p:String = t.example.ToLower()

			Local path:String = absDocDir+"/"+p

			If Not FileType(path) Then
				' try one level up...
				path = ExtractDir(absDocDir) + "/"+p
			End If

			Local code$=LoadText(path).Trim()
			For Local line:String = EachIn code.Split("~n")
				Emit line
			Next
			Emit "```"

		EndIf	
	End Method

End Type
