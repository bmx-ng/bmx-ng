SuperStrict

Framework brl.standardio

' This function takes the pointer to an integer variable
' and adds 1 by treating the variable's memory as an array...

Function AddToVariable (addee:Int Ptr)
         addee [0] = addee [0] + 1
End Function

' Test variable, looking forward to a brave new world...

Local a:Int = 5

' Pass the address of 'a' to function...

AddToVariable (Varptr (a))

' The result...

Print "Variable a was 5... now it's " + a


