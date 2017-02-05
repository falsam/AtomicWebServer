EnableExplicit

Global Title.s = "Atomic Web Server v2.0"

Global Port = 6832

Global WWWDirectory.s = "www/"
Global WWWIndex.s = "index.html"
Global WWWError.s = "error.html"

Global WEvent, SEvent, ClientID

Global *Buffer = AllocateMemory(10000)

;Compteur de vues
Structure NewView
  count.i
EndStructure
Global CountViews.NewView

;Plan de l'application
Declare Start()                                                 ;Affichage application
Declare ProcessRequest()                                        ;Demande de traitement 
Declare BuildRequestHeader(*Buffer, DataLength, ContentType.s)  ;Modification entete HTTP
Declare Exit()                                                  ;Sortie de l'application

Start()

;Affichage application
Procedure Start()
  ;Initialisation environnement réseau
  If Not InitNetwork() 
    MessageRequester(Title, "Impossible d'initialiser l'environnement réseau.", 0)
  Else     
    
    ;Création du serveur 
    If CreateNetworkServer(0, Port)
      
      ;Chargement du compteur de vues
      If LoadJSON(0, "server.json")
        ExtractJSONStructure(JSONValue(0), @CountViews, NewView)
      EndIf
      
      ;Affichage de l'application
      OpenWindow(0, 0, 0, 800, 600, Title)
      EditorGadget(0, 0, 0, 800, 600, #PB_Editor_ReadOnly)
      AddGadgetItem(0, -1, "Serveur en écoute sur le port " + Port)
      
      ;Déclencheur
      BindEvent(#PB_Event_CloseWindow, @Exit())
      
      Repeat    
        Repeat : Until WindowEvent() = 0
        
        SEvent = NetworkServerEvent()
        
        If SEvent
          ClientID = EventClient()
          
          Select SEvent
            Case #PB_NetworkEvent_Connect     ; Client se connecte
            Case #PB_NetworkEvent_Disconnect  ; Client se deconnecte 
            Default 
              ReceiveNetworkData(ClientID, *Buffer, 10000)
              ProcessRequest()
          EndSelect
        Else
          Delay(10)  ; Ne pas saturer le CPU
        EndIf
      ForEver     
    Else
      MessageRequester(Title, "Impossible de créer le serveur sur le port " + port)
    EndIf
  EndIf
EndProcedure

;Demande de traitement
Procedure ProcessRequest()
  Protected RequestedFile.s, FileLength, MaxPosition, Position, ContentType.s
  Protected *FileBuffer
  Protected BufferOffset.s, *BufferOffset
  Protected Buffer.s = PeekS(*Buffer, -1, #PB_UTF8)
  Protected Result.s
    
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
    
    AddGadgetItem(0, -1, "Client IP " + IPString(GetClientIP(ClientID)) + " load " + RequestedFile) 
    
    ; Test if the file exists, and if not display the error message
    If ReadFile(0, WWWDirectory + RequestedFile)
      
      ;Préparation de la page HTML à envoyer
      FileLength = Lof(0)
      
      ;Entete HTTP : Definition du content-type (Type de média à envoyer au navigateur)
      ;Ref : https://fr.wikipedia.org/wiki/Type_MIME
      Select Right(RequestedFile, 4)
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
      
      *FileBuffer   = AllocateMemory(FileLength + 200)
      *BufferOffset = BuildRequestHeader(*FileBuffer, FileLength, ContentType)
      
      ReadData(0, *BufferOffset, FileLength)
      CloseFile(0)
      
      ;Mise à jour des pseudo variables de la page index.html 
      If RequestedFile = WWWIndex
        CountViews\count + 1
        
        BufferOffset = PeekS(*BufferOffset, -1, #PB_UTF8) 
        Result = ReplaceString(BufferOffset, "{{userip}}", IPString(GetClientIP(ClientID))) : BufferOffset = Result
        Result = ReplaceString(BufferOffset, "{{countviews}}", Str(CountViews\count)) 
        PokeS(*BufferOffset, Result, -1, #PB_UTF8) ;StringByteLength(Buffer, #PB_UTF8)
      EndIf       
    Else
      
      ;La page HTML demandée n'existe pas : Affichage de la page d'erreur
      If ReadFile(0, WWWDirectory + WWWError, #PB_UTF8)
        FileLength = Lof(0)
        ContentType = "text/html"
        
        *FileBuffer   = AllocateMemory(FileLength + 200)
        *BufferOffset = BuildRequestHeader(*FileBuffer, FileLength, ContentType)
        
        ReadData(0, *BufferOffset, FileLength)
        CloseFile(0)       
        
        BufferOffset = PeekS(*BufferOffset, -1, #PB_UTF8) 
        Result = ReplaceString(BufferOffset, "{{countviews}}", Str(CountViews\count)) 
        PokeS(*BufferOffset, Result, -1, #PB_UTF8)
      EndIf
    EndIf
    
    ;Envoie des données au client
    SendNetworkData(ClientID, *FileBuffer, *BufferOffset - *FileBuffer + FileLength)
    ;SendNetworkData(ClientID, *FileBuffer, FileLength)
    FreeMemory(*FileBuffer)
  EndIf  
EndProcedure

;Modification entete HTTP
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

;Sortie de l'application
Procedure Exit()
  CloseNetworkServer(0)
  
  ;Sauvegarde du compteur de vues
  CreateJSON(0)
  InsertJSONStructure(JSONValue(0), @CountViews, NewView)
  SaveJSON(0, "server.json")
  
  End
EndProcedure
; IDE Options = PureBasic 5.42 LTS (Windows - x86)
; CursorPosition = 144
; FirstLine = 126
; Folding = -
; Markers = 94,130
; EnableUnicode
; EnableXP
; Executable = server.exe