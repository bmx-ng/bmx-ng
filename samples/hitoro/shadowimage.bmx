SuperStrict

Framework SDL.SDLRenderMax2d
Import brl.pngloader
Import brl.Random

' Rockets rotating and casting alpha-blended, pseudo light-sourced shadows on each other...

Local MAXNUM:Int = 500

Graphics 640, 480, 0

AutoImageFlags MASKEDIMAGE

SetMaskColor 255, 0, 255

Local rocket:TImage = LoadImage ("gfx/boing.png",MASKEDIMAGE|MIPMAPPEDIMAGE)
Local grass:TImage = LoadImage ("gfx/grass.png")

MidHandleImage rocket

Local scale# = 0.5
Local trans# = 0.5

Local NUM:Int = MAXNUM

Local x:Int[NUM], y:Int[NUM]
Local xs:Int[NUM], ys:Int[NUM]
Local ang# [NUM], angstep# [NUM]

For Local loop:Int = 0 To NUM - 1
	x [loop] = Rand (0, GraphicsWidth () - 1)
	y [loop] = Rand (0, GraphicsHeight () - 1)
	xs [loop] = Rand (1, 5)
	ys [loop] = Rand (1, 5)
	ang [loop] = Rand (0, 359)
	angstep [loop] = Rnd (1, 5)
Next

NUM = 1

Repeat

	Cls

        If KeyHit (KEY_RIGHT) Or MouseHit (2)
           If NUM < MAXNUM Then NUM = NUM + 1
        Else
            If KeyHit (KEY_LEFT) Or MouseHit (1)
               If NUM > 1 Then NUM = NUM - 1
            EndIf
        EndIf

	Local mx:Int = MouseX ()
	Local my:Int = MouseY ()

        SetScale scale, scale
	SetRotation 0
	TileImage(grass,0,0)

	For Local loop:Int = 0 To NUM - 1

		x [loop] = x [loop] + xs [loop]
		y [loop] = y [loop] + ys [loop]

		If x [loop] < 0 Or x [loop] > GraphicsWidth () - 1
		   xs [loop] = -xs [loop]; x [loop] = x [loop] + xs [loop]
		   angstep [loop] = -angstep [loop]
		EndIf

		If y [loop] < 0 Or y [loop] > GraphicsHeight () - 1
		   ys [loop] = -ys [loop]; y [loop] = y [loop] + ys [loop]
		   angstep [loop] = -angstep [loop]
		EndIf

		ang [loop] = ang [loop] + angstep [loop]
                If ang [loop] > 360 - angstep [loop] Then ang [loop] = 0
		SetRotation ang [loop]

		Local offx:Int = -(mx - x [loop]) / 8
		Local offy:Int = -(my - y [loop]) / 8
		DrawShadowedImage rocket, x [loop], y [loop], offx, offy, trans

	Next

        SetScale 1, 1
        DrawShadowText "Use left/right cursors or mouse buttons to add/remove rockets", 20, 20
        DrawShadowText "Move mouse to change light direction", 20, 40
        DrawShadowText "Number of rockets: " + NUM, 20, 80

	Flip

Until KeyHit (KEY_ESCAPE)

End

Function DrawShadowText (t$, x:Int, y:Int)
      SetRotation 0
      SetColor 0, 0, 0
      DrawText t$, x + 1, y + 1
      SetColor 255, 255, 255
      DrawText t$, x, y
End Function

Function DrawShadowedImage (image:TImage, x#, y#, xoff#, yoff#, level#)

	SetBlend ALPHABLEND
	SetColor 0, 0, 0
	SetAlpha level
	DrawImage image, x + xoff, y + yoff

	SetBlend MASKBLEND
	SetColor 255, 255, 255
	SetAlpha 1
	DrawImage image, x, y

End Function

