SuperStrict

?win32
Framework SDL.d3d9sdlmax2d
?Not win32
Framework SDL.gl2sdlmax2d
?
Import brl.pngloader
Import brl.Random

' Ugly -- just playing around!

Global FlameList:TList = New TList
Global ShotList:TList = New TList

Type Flame
	Field x#, y#
	Field image:TImage
	Field ALPHA#
	Field scale#
	Field ys#
End Type

Type Shot
	Field x#, y#
	Field xs#, ys#
	Field ALPHA#
End Type

Graphics 640, 480, 0

AutoImageFlags MASKEDIMAGE

SetClsColor 16, 32, 64

SetMaskColor 255, 0, 255

Local player:TImage = LoadImage ("gfx/boing.png")
MidHandleImage player

Local flm:TImage = LoadImage ("gfx/flame.png")
MidHandleImage flm

Local sky:TImage = LoadImage ("gfx/sky.png")
Local grass:TImage = LoadImage ("gfx/grass.png")
Local rock:TImage = LoadImage ("gfx/rock.png")
Local water:TImage = LoadImage ("gfx/water.png")

MidHandleImage grass
MidHandleImage rock
MidHandleImage water

Local x# = GraphicsWidth () / 2
Local y# = GraphicsHeight () / 2

Local speed# = 0

Local playerscale# = 0.25

' Map tiles...

Local MAPXS:Int = 50
Local MAPYS:Int = 30

Local map:TImage[MAPXS, MAPYS]

For Local mapx:Int = 0 To MAPXS - 1

	For Local mapy:Int = 0 To MAPYS - 1

		Local image:TImage
		Select Rand (0, 3)
			Case 0
				image = Null
			Case 1
				image = grass
			Case 2
				image = rock
			Case 3
				image = water
		End Select

		map [mapx, mapy] = image

	Next

Next

Local GW2:Int = GraphicsWidth () / 2
Local GH2:Int = GraphicsHeight () / 2

Local ShotSpeed# = 4

Repeat

	Local mx:Int = MouseX ()
	Local my:Int = MouseY ()
	
	Cls
	
	SetBlend SOLIDBLEND
	TileImage sky

	Local ang# = ATan2 (my - GH2, mx - GW2)

	x = x + Cos (ang) * speed
	y = y + Sin (ang) * speed
	
	If KeyHit (KEY_SPACE)
		Local s:Shot = New Shot
		s.x = (x + Cos (ang) * (ImageWidth (player) * playerscale) / 2)
		s.y = (y + Sin (ang) * (ImageHeight (player) * playerscale)/ 2)
		s.xs = Cos (ang) * (speed + ShotSpeed)
		s.ys = Sin (ang) * (speed + ShotSpeed)
		s.ALPHA = 1
		ShotList.AddLast s
	EndIf
	
	If MouseDown (1)
		If speed < 10 Then speed = speed + 0.1
		If Rand (1, 100) > (100 - speed * 2.5)
			Local f:Flame = New Flame
			f.x = Rand (1, 8) + (x - Cos (ang) * (ImageWidth (player) * playerscale) / 2)
			f.y = Rand (1, 8) + (y - Sin (ang) * (ImageHeight (player) * playerscale)/ 2)
			f.ys = 0
			f.image = flm
			f.ALPHA = 1
			f.scale = 0.5
			FlameList.AddLast f
		EndIf
	EndIf
	
	SetBlend MASKBLEND
	
	SetRotation 0
	SetScale 1, 1
	
	For Local mapx:Int = 0 To MAPXS - 1
		For Local mapy:Int = 0 To MAPYS - 1
			If map [mapx, mapy]
				DrawImage map [mapx, mapy], mapx * 128 - x, mapy * 128 - y
			EndIf
		Next
	Next
	
	SetColor 255, 255, 255
	SetBlend ALPHABLEND
	
	For Local p:Flame=EachIn FlameList
		p.ys = p.ys - 0.05
		p.y = p.y + p.ys
		SetAlpha p.ALPHA
		SetScale p.scale, p.scale
		SetRotation 0
		DrawImage p.image, GW2 + p.x - x, GH2 + p.y - y
		p.ALPHA = p.ALPHA - 0.01
		p.scale = p.scale + Rnd (0.0025, 0.05)
		If p.ALPHA < 0
			FlameList.remove p
		EndIf
	Next
	
	SetColor 255, 255, 0
	
	For Local s:Shot = EachIn ShotList
		s.x = s.x + s.xs
		s.y = s.y + s.ys
		SetAlpha s.ALPHA
		SetRotation 0
		SetScale 1, 1
		DrawRect GW2 + s.x - x, GH2 + s.y - y, 8, 8
		s.ALPHA = s.ALPHA - 0.01
		If s.ALPHA < 0
			ShotList.remove s
		EndIf
	Next
	
	SetBlend ALPHABLEND
	SetAlpha 0.25
	SetScale 0.25, 0.25
	SetColor 0, 0, 0
	Local sp2:Int = speed * 2
	DrawPointedImage player, GW2 + sp2, GH2 + sp2, mx + sp2, my + sp2

	SetColor 255, 255, 255
	SetBlend MASKBLEND
	SetScale 0.25, 0.25
	SetAlpha 1
	DrawPointedImage player, GW2, GH2, mx, my

	speed = speed - 0.075; If speed < 0 Then speed = 0

	SetRotation 0
	SetScale 1, 1
	SetColor 0, 0, 0
	DrawText "Hold left mouse button to move and hit space to fire...", 21, 21
	SetColor 255, 255, 255
	DrawText "Hold left mouse button to move and hit space to fire...", 20, 20
	
	Flip

Until KeyHit (KEY_ESCAPE)

End

' Assumes image is oriented 'upwards' by default -- fiddle with
' the "+ 90" part on the first line if not!

Function DrawPointedImage (image:TImage, x#, y#, targetx#, targety# )
	Local ang# = ATan2 (targety - y, targetx - x) + 90
	SetRotation ang
	DrawImage image, x, y
End Function

