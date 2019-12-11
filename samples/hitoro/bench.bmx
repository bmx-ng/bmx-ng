SuperStrict

Framework brl.standardio

' Ported from another Basic for benchmarking purposes...

Const ITERATIONS:Int = 10000

Local Flags:Int [8191]
Print "SIEVE OF ERATOSTHENES - " + ITERATIONS + " iterations"

Local X:Int = MilliSecs ()

Local Count:Int

For Local Iter:Int = 1 To ITERATIONS

	Count = 0

  For Local I:Int = 0 To 8190
    Flags[I] = 1
  Next

  For Local I:Int = 0 To 8190
    If Flags[I]=1 Then
       Local Prime:Int = I + I
       Prime = Prime + 3
       Local K:Int = I + Prime
       While K <= 8190
         Flags[K] = 0
         K = K + Prime
       Wend
       Count = Count + 1
    EndIf
  Next

Next

X = MilliSecs () - X

Print "1000 iterations took "+(X/1000.0)+" seconds."
Print "Primes: "+Count
End

