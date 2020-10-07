SuperStrict

?win32
Framework SDL.d3d9sdlmax2d
?Not win32
Framework SDL.gl2sdlmax2d
?
Import brl.pngloader
Import brl.ramstream
Import brl.linkedlist
Import brl.RandomDefault

Const PARTICLE_GRAVITY# = 0.05

Global ParticleCounter:Int
Global ParticleList:TList = New TList

' Core abstract type...

Type Atom

	Field image:TImage
	Field x#
	Field y#
	Field xs#
	Field ys#
	Field ALPHA# = 1
	Field size#
	
	Method Update () Abstract

End Type

' Generic particle type that holds creation/update functions, based
' on abstract type Atom...

Type Particle Extends Atom

	Function Create:Particle (image:TImage, x#, y#, xs#, ys#)
		Local p:Rocket = New Rocket
		p.image = image
		p.x = x
		p.y = y
		p.xs = xs
		p.ys = ys
		ParticleList.AddLast p
		ParticleCounter = ParticleCounter + 1
		Return p
	End Function

	Function UpdateAll ()
		Local p:Atom
		For Local p:Particle = EachIn ParticleList
	      	p.Update ()
		Next
	End Function

End Type

' Types based on Particle, all to be created using EXTENDED_TYPE.Create ()...

Type Rocket Extends Particle

	Method Update ()
		If ALPHA > 0.01
			ALPHA = ALPHA - 0.005
			SetAlpha ALPHA
			ys = ys + PARTICLE_GRAVITY
			x = x + xs
			y = y + ys
			Local ang# = ATan2 (xs, -ys)
			SetRotation ang
			DrawImage image, x, y
			If x < 0 Or x > GraphicsWidth () Or y > GraphicsHeight ()
				ParticleList.Remove Self
				ParticleCounter = ParticleCounter - 1
			EndIf
		Else
			ParticleList.Remove Self
			ParticleCounter = ParticleCounter - 1
		EndIf
	End Method

End Type

' --------------------------------------------------------------------------------

Incbin "gfx/boing.png"

Const GAME_WIDTH:Int = 640
Const GAME_HEIGHT:Int = 480

Const GRAPHICS_WIDTH:Int = 1024
Const GRAPHICS_HEIGHT:Int = 768

Graphics GRAPHICS_WIDTH,GRAPHICS_HEIGHT,0

SetVirtualResolution GAME_WIDTH,GAME_HEIGHT

SetClsColor 64, 96, 180

SetMaskColor 255, 0, 255
AutoImageFlags MASKEDIMAGE ' Disable for filtered rockets...

Local image:TImage = LoadImage ("incbin::gfx/boing.png")
MidHandleImage image

Local lastmousex:Int = VirtualMouseX ()
Local lastmousey:Int = VirtualMouseY ()

Repeat

	Local x:Int = VirtualMouseX ()
	Local y:Int = VirtualMouseY ()

	Local mxs# = VirtualMouseXSpeed ()'# = x - lastmousex
	Local mys# = VirtualMouseYSpeed ()'# = y - lastmousey

	Cls

	Local xs# = mxs / 10 + Rnd (-0.1, 0.1)
	Local ys# = mys / 10 + Rnd (-0.1, 0.1)

	If MouseDown (1) And (mxs Or mys)
		Rocket.Create (image, x, y, xs, ys)
	EndIf

        SetScale 0.2, 0.2
	SetBlend ALPHABLEND
	Particle.UpdateAll ()

        SetScale 1, 1
        SetRotation 0

	DrawText "Click and drag mouse to throw rockets!", 10, 10
	DrawText "Rockets: " + ParticleCounter, 10, 25

	Flip

	lastmousex = x
	lastmousey = y

Until KeyHit (KEY_ESCAPE)

End
