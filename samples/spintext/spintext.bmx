SuperStrict

?win32
Framework SDL.d3d9sdlmax2d
?Not win32
Framework SDL.gl2sdlmax2d
?

Graphics 640,480, 0

Local t:String="***** Some spinny text *****"
Local w:Int=TextWidth(t)
Local h:Int=TextHeight(t)

Local r#=0

While Not KeyHit( KEY_ESCAPE )

	Cls
	
	r:+3
	SetOrigin 320,240
	SetHandle w/2,h/2
	SetTransform r,3,5

	SetColor 0,0,255
	DrawRect 0,0,w,h
	SetColor 255,255,255
	DrawText t,0,0

	SetOrigin 0,0
	SetHandle 0,0	
	SetTransform 0,1,1
	
	Flip

Wend
	