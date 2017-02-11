EnableExplicit

Global Title.s = "Atomic Web Server v2.0"

Global Port = 6833

Global WWWDirectory.s = "www/"
Global WWWIndex.s = "index.html"
Global WWWError.s = "error.html"

Global BufferSize = 1024, *Buffer = AllocateMemory(BufferSize), Buffer.s

Global ClientID

Declare Start()                                                 
Declare ProcessRequest()                                         
Declare BuildRequestHeader(*Buffer, DataLength, ContentType.s)  
Declare Exit()                                                  

Start()

;Affichage / Show application
Procedure Start()
  Protected ServerEvent, Result
  
  If Not InitNetwork() 
    MessageRequester(Title, "Can't initialize the network !", 0)
  Else     
    
    ;Création du serveur / Create server 
    If CreateNetworkServer(0, Port)      
      OpenWindow(0, 0, 0, 800, 600, Title)
      EditorGadget(0, 0, 0, 800, 560, #PB_Editor_ReadOnly)
      AddGadgetItem(0, -1, "Server listening on port " + Port)
      
      CheckBoxGadget(1, 10, 570, 200, 22, "Show Log") 
      SetGadgetState(1, #PB_Checkbox_Checked)
      
      ;Déclencheur / Trigger
      BindEvent(#PB_Event_CloseWindow, @Exit())
      
      Repeat    
        Repeat : Until WindowEvent() = 0
        
        ServerEvent = NetworkServerEvent()
        If ServerEvent
          ClientID = EventClient()
          Buffer = ""
          Select ServerEvent              
            Case #PB_NetworkEvent_Data 
              Repeat
                FreeMemory(*Buffer)
                *Buffer = AllocateMemory(BufferSize)
                Result = ReceiveNetworkData(ClientID, *Buffer, BufferSize)
                Buffer + PeekS(*Buffer, -1, #PB_UTF8)
              Until Result <> BufferSize
              
              ProcessRequest()
          EndSelect
        Else
          Delay(10)  ; Ne pas saturer le CPU / Don't stole the whole CPU !
        EndIf
      ForEver     
    Else
      MessageRequester(Title, "Error: can't create the server (port " + port + " in use ?)")
    EndIf
  EndIf
EndProcedure

;Demande de traitement / Process Request
Procedure ProcessRequest()
  Protected RequestedFile.s, FileLength, MaxPosition, Position, ContentType.s
  Protected *FileBuffer
  Protected BufferOffset.s, *BufferOffset
  
  If Left(Buffer, 3) = "GET"    
    MaxPosition = FindString(Buffer, Chr(13), 5)
    Position = FindString(Buffer, " ", 5)
    If Position < MaxPosition
      RequestedFile = Mid(Buffer, 6, Position-5)      ; Automatically remove the leading '/'
      RequestedFile = RTrim(RequestedFile)
    Else
      RequestedFile = Mid(Buffer, 6, MaxPosition-5)   ; When a command like 'GET /' is sent..
    EndIf
    
    If RequestedFile = ""
      RequestedFile = WWWIndex      
    EndIf
    
    ;Mise à jour du log / UPdated log
    If GetGadgetState(1) = #PB_Checkbox_Checked
      AddGadgetItem(0, -1, "Client IP " + IPString(GetClientIP(ClientID)) + " load " + RequestedFile) 
    EndIf   
      
    ;Envoyer la page HTML au client / Send the HTML page to the client
    If ReadFile(0, WWWDirectory + RequestedFile)
      
      ;Préparation de la page HTML à envoyer
      FileLength = Lof(0)
      
      ;Definition du content-type / Setup content-type
      ;Ref : https://fr.wikipedia.org/wiki/Type_MIME
      Select GetExtensionPart(RequestedFile)
        Case ".css" : ContentType = "text/css"
        Case ".js"  : ContentType = "application/javascript" 
        Case ".gif" : ContentType = "image/gif"
        Case ".jpg" : ContentType = "image/jpeg"
        Case ".png" : ContentType = "image/png"
        Case ".txt" : ContentType = "text/plain"
        Case ".zip" : ContentType = "application/zip"
        Case ".pdf" : ContentType = "application/pdf"
          
        Default     
          ContentType = "text/html" 
      EndSelect      
      
    Else
      
      ;Affichage de la page d'erreur si url inexistant / Display error page if url nonexistent
      If ReadFile(0, WWWDirectory + WWWError, #PB_UTF8)
        FileLength = Lof(0)
        ContentType = "text/html"        
      EndIf
    EndIf
    
    ;Envoie des données au client / Sends data to the client
    *FileBuffer   = AllocateMemory(FileLength + 200)
    *BufferOffset = BuildRequestHeader(*FileBuffer, FileLength, ContentType)
    ReadData(0, *BufferOffset, FileLength)
    CloseFile(0)
    
    SendNetworkData(ClientID, *FileBuffer, *BufferOffset - *FileBuffer + FileLength)
    FreeMemory(*FileBuffer)
  EndIf  
EndProcedure

;Modification entete HTTP / Edit HTTP header
Procedure BuildRequestHeader(*FileBuffer, FileLength, ContentType.s)
  Protected Length
  Protected Week.s = "Sun, Mon,Tue,Wed,Thu,Fri,Sat"
  Protected MonthsOfYear.s = "Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec" 
  
  Protected DayOfWeek.s = StringField("Sun, Mon,Tue,Wed,Thu,Fri,Sat", DayOfWeek(Date()) + 1, ",")
  Protected Day = Day(Date())
  Protected Month.s = StringField("Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec", Month(Date()), ",")
  Protected Year.s = Str(Year(Date()))
  Protected Time.s = FormatDate("%hh:%ii:%ss GMT", Date())
  
  Length = PokeS(*FileBuffer, "HTTP/1.1 200 OK" + #CRLF$, -1, #PB_UTF8)                                                             : *FileBuffer + Length
  Length = PokeS(*FileBuffer, "Date: " + DayOfWeek + ", " + Day + " " + Month + " " + Year + " " + Time  + #CRLF$, -1, #PB_UTF8)    : *FileBuffer + Length
  Length = PokeS(*FileBuffer, "Server: "+ Title + #CRLF$, -1, #PB_UTF8)                                                             : *FileBuffer + Length
  Length = PokeS(*FileBuffer, "Content-Length: " + Str(FileLength) + #CRLF$, -1, #PB_UTF8)                                          : *FileBuffer + Length
  Length = PokeS(*FileBuffer, "Content-Type: " + ContentType + #CRLF$, -1, #PB_UTF8)                                                : *FileBuffer + Length
  Length = PokeS(*FileBuffer, #CRLF$, -1, #PB_UTF8)                                                                                 : *FileBuffer + Length
  
  ProcedureReturn *FileBuffer
EndProcedure

;Sortie  / Exit 
Procedure Exit()
  CloseNetworkServer(0)  
  End
EndProcedure
; IDE Options = PureBasic 5.42 LTS (Windows - x86)
; CursorPosition = 74
; FirstLine = 69
; Folding = -
; Markers = 85,117
; EnableUnicode
; EnableXP
; Executable = server.exe