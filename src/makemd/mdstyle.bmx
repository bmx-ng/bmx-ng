
Strict

Import "docstyle.bmx"

Type TRstStyle Extends TDocStyle

	Method EmitHeader()


		If doc.kind = "/" Return

		If doc.kind = "Module" Or doc.kind = "Type" Or doc.kind = "Interface" Or doc.kind = "Struct" Or doc.kind = "Enum" Then
			Emit "---"
			Emit "id: " + doc.id.ToLower() 
			Emit "title: " + doc.id
			
			Local label:String = doc.id
			If doc.needsIntro Then
				label = "Introduction to " + doc.id
			End If
			Emit "sidebar_label: " + label
			Emit "---"
			Emit ""
		End If
		
		Local s:String
		
		If doc.kind <> "Module" And doc.kind <> "Type" And doc.kind <> "Interface" And doc.kind <> "Struct"  And doc.kind <> "Enum" Then
			Emit s + doc.id
		End If

		If (doc.kind = "Type" Or doc.kind = "Interface" Or doc.kind = "Struct" Or doc.kind = "Enum") And doc.bbdoc Then
			Emit doc.bbdoc
			Emit ""
		EndIf
		
		Emit ""

		If doc.about Then
			Emit doc.about
			Emit ""
		End If
		
		If doc.kind = "Type" Or doc.kind = "Interface" Or doc.kind = "Struct" Or doc.kind = "Enum" Then
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
	
	Method EmitDecls( parent:TDocNode, kind$, category:String = Null )
		Local list:TList=ChildList( kind )
		If Not list Return

		Local title:String
		Local emittedTitle:Int
		
		If category And category <> "-" Then
			title = "## " + category + "s"
		Else
			title = "## " + kind + "s"
		End If

		'Emit ""
		
		For Local t:TDocNode=EachIn list
		
			If category Then
				Local id:String = t.id.ToLower()
				Select category
					Case "-"
						If id = "new" Or id = "delete" Or t.op Then
							Continue
						End If
					Case "Constructor"
						If id <> "new" Then
							Continue
						End If
					Case "Destructor"
						If id <> "delete" Then
							Continue
						End If
					Case "Operator"
						If Not t.op Then
							Continue
						End If
				End Select
			End If
			
			If Not emittedTitle Then
				Emit title
				Emit ""
				emittedTitle = True
			End If

			Local s:String
			
			Emit "### `" + t.proto.orig + "`"
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

		If t.examples.Count()
			Local showCount:Int = t.examples.Count() > 1
			
			Local count:Int
			For Local example:String = EachIn t.examples
				count :+ 1
				
				Local title:String = "#### Example"
				If showCount Then
					title :+ " " + count
				End If
				EmitSource title
				EmitSource "```blitzmax"

				Local p:String = example.ToLower()

				Local path:String = absDocDir+"/"+p

				If Not FileType(path) Then
					' try one level up...
					path = ExtractDir(absDocDir) + "/"+p
				End If

				Local code$=LoadText(path).Trim()
				For Local line:String = EachIn code.Split("~n")
					EmitSource line
				Next
				EmitSource "```"
			Next
		EndIf	
	End Method

End Type
