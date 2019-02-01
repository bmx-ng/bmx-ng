
Strict

Global OPERATORS:String[] = ["*", "/", "+", "-", "&", "|", "~~", "^", ":*", ":/", ..
		":+", ":-", ":&", ":|", ":~~", ":^", "<", "<=", ">", ">=", ..
		"=", "<>", "mod", "shl", "shr", ":mod", ":shl", ":shr", "[]", "[]="]
Global OPERATOR_MAP:String[] = ["_mul", "_div", "_add", "_sub", "_and", "_or", "_xor", "_pow", "_muleq", ..
		"_diveq", "_addeq", "_subeq", "_andeq", "_oreq", "_xoreq", "_poweq", "_lt", "_le", "_gt", ..
		"_ge", "_eq", "_ne", "_mod", "_shl", "_shr", "_modeq", "_shleq", "_shreq", "_iget", "_iset"]

Function IsAlphaChar( char )
	Return (char>=Asc("A") And char<=Asc("Z")) Or (char>=Asc("a") And char<=Asc("z")) Or (char=Asc("_"))
End Function

Function IsProtoAlphaChar( char )
	Return (char>=Asc("A") And char<=Asc("Z")) Or (char>=Asc("a") And char<=Asc("z"))
End Function

Function IsDecChar( char )
	Return (char>=Asc("0") And char<=Asc("9"))
End Function

Function IsIdentChar( char )
	Return IsAlphaChar( char ) Or IsDecChar( char )
End Function

Function IsProtoIdentChar( char )
	Return IsProtoAlphaChar( char ) Or IsDecChar( char )
End Function

Function IsHexChar( char )
	Return IsDecChar( char ) Or (char>=Asc("A") And char<=Asc("F")) Or (char>=Asc("a") And char<=Asc("f"))
End Function

Function IsBinChar( char )
	Return (char>=Asc("0") And char<=Asc("1"))
End Function

Function IsPunctChar( char )
	Select char
	Case Asc("."),Asc(","),Asc(";"),Asc(":" ),Asc("!"),Asc("?") Return True
	End Select
End Function

Function ParseWS$( t$,i Var )
	Local i0=i
	While i<t.length And t[i]<=32
		i:+1
	Wend
	Return t[i0..i]
End Function

Function ParseIdent$( t$,i Var )
	ParseWS t,i
	Local i0=i
	If i<t.length And IsAlphaChar( t[i] )
		i:+1
		While i<t.length And (IsIdentChar( t[i] ) Or t[i]=Asc("."))
			i:+1
		Wend
	EndIf
	Return t[i0..i]
End Function

Function ParseOperator:String(t:String, i:Int Var)
	ParseWS t, i
	Local i0=i
	For Local n:Int = 0 Until OPERATORS.length
		Local op:String = OPERATORS[n]
		Local o:String = t[i..i + op.length]
		If op = o Then
			i :+ op.length
			Return OPERATOR_MAP[n]
		End If
	Next
End Function

Function ParseString$( t$,i Var )
	ParseWS t,i
	If i=t.length Or t[i]<>Asc("~q") Return
	i:+1
	Local i0=i
	While i<t.length And t[i]<>Asc("~q" )
		i:+1
	Wend
	Local q$=t[i0..i]
	If i<t.length i:+1
	Return q
End Function
