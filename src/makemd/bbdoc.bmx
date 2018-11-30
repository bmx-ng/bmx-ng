
Strict

Import "parse.bmx"

'still pretty ugly - could probably be done in a few lines with Bah.RegEx!

Type TBBLinkResolver

	Method ResolveLink$( link$ ) Abstract

End Type

Private

'finds a 'span' style tag starting at index i - eg: @bold or @{this is bold}
'
'returns bit after tag, fills in b and e with begin and end of range.
Function FindBBTag$( Text$,tag$,i,b Var,e Var )
	Repeat
		i=Text.Find( tag,i )
		If i=-1 Return
		If Text[i + 1] = Asc(tag) Or Text[i+1] = 32 Then ' ignore tag sequences
			i :+ 6
			Continue
		End If
		If i=0 Or Text[i-1]<=32 Or Text[i-1]=Asc(">") Exit
		i:+tag.length
	Forever
	b=i
	i:+1
	If i=Text.length Return
	Local t$
	If Text[i]=Asc("{")
		i:+1
		While i<Text.length And Text[i]<>Asc("}")
			i:+1
		Wend
		t=Text[b+2..i]
		If i<Text.length i:+1
		e=i
	Else
		i:+1
		While i<Text.length And (IsIdentChar(Text[i]) Or Text[i]=Asc("."))
			i:+1
		Wend
		If Text[i-1]=Asc(".") i:-1
		t=Text[b+1..i]		
		e=i
	EndIf
	Return t
End Function

'does simple html tags, bold, italic etc.	
Function FormatBBTags( Text$ Var,bbTag$,htmlTag$ )
	Local i
	Repeat
		Local b,e
		Local t$=FindBBTag( Text,bbTag,i,b,e )
		If Not t Return
		
		t="<"+htmlTag+">"+t+"</"+htmlTag+">"
		Text=Text[..b]+t+Text[e..]
		i=b+t.length
	Forever
End Function

Public

Function BBToHtml2$( Text$,doc:TBBLinkResolver )
	Local i
	
	'headings
	i=0
	Local hl=1
	Repeat
		i=Text.Find( "~n+",i )
		If i=-1 Exit
		
		Local i2=Text.Find( "~n",i+2 )
		If i2=-1 Exit
		
		Local q$=Text[i+2..i2]
		q="<h"+hl+">"+q+"</h"+hl+">"
		
		If hl=1 hl=2
		
		Text=Text[..i]+q+Text[i2..]
		i:+q.length
	Forever
	
	'tables
	i=0
	Repeat
		i=Text.Find( "~n[",i )
		If i=-1 Exit
		
		Local i2=Text.Find( "~n]",i+2 )
		If i2=-1 Exit
		
		Local q$=Text[i+2..i2]
		
		If q.Find( " | " )=-1	'list?
			'q=q.Replace( "~n*","<li>" )
			'q="<ul>"+q+"</ul>"
		Else
			q=q.Replace( "~n*","</td></tr><tr><td> " )
			q=q.Replace( " | ","</td><td>" )
			q="~n<table><tr><td>"+q+"</table>~n"
		EndIf
		
		Text=Text[..i]+q+Text[i2+2..]
		i:+q.length
	Forever
	
	'quotes
	i=0
	Repeat
		i=Text.Find( "~n{",i )
		If i=-1 Exit
		
		Local i2=Text.Find(  "~n}",i+2 )
		If i2=-1 Exit
		
		Local q$=Text[i+2..i2]
		
		q="<blockquote>"+q+"</blockquote>"
		
		Text=Text[..i]+q+Text[i2+2..]
		i:+q.length
	Forever
	
	' images
	i = 0
	Repeat
		i = Text.Find("<img src=", i)
		If i = -1 Exit

		Local i2:Int = Text.Find(">", i)
		
		Local s1:Int = Text.Find("~q", i)
		Local s2:Int = Text.Find("~q", s1 + 2)
		
		If s1 > 0 And s2 > 0 Then
			Local q:String = "![](assets/"+ Text[s1 + 1..s2] + ")"
			Text = Text[..i] + q + Text[i2 + 1..]
			i :+ q.length
		Else
			Exit
		End If
	Forever
	
	'links
	i=0
	Repeat
		Local b,e
		Local t$=FindBBTag( Text,"#",i,b,e )
		If Not t Exit
		
		t=doc.ResolveLink( t )
		Text=Text[..b]+t+Text[e..]
		i=b+t.length
	Forever
	
	'span tags
	FormatBBTags Text,"@","b"

	FormatBBTags Text,"%","i"

	'escapes
	i=0
	Repeat
		i=Text.Find( "~~",i )
		If i=-1 Or i=Text.length-1 Exit
		
		Local r$=Chr( Text[i+1] )
		Select r
		Case "<" r="&lt;"
		Case ">" r="&gt;"
		End Select
		
		Text=Text[..i]+r+Text[i+2..]
		i:+r.length
	Forever
	
	Return Text
	
End Function

'bbdoc to html conversion
Function BBToHtml$( Text$,doc:TBBLinkResolver )
	
	Text=Text.Replace( "~r~n","~n" )
	
	Local out$,i
	
	'preformatted code...
	Repeat
		Local i1=Text.Find( "~n{{",i )
		If i1=-1 Exit

		Local i2=Text.Find(  "~n}}",i+3 )
		If i2=-1 Exit
		
		out:+BBToHtml2( Text[i..i1],doc )
		
		out:+"~n```~n"+Text[i1+3..i2].Trim()+"~n````~n"
		
		i=i2+3
	Forever
	
	out:+BBToHtml2( Text[i..],doc )
	
	Return out
	
End Function	
		
