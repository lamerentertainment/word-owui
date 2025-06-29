VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} frmPromptTool 
   Caption         =   "KI Plugin"
   ClientHeight    =   6720
   ClientLeft      =   110
   ClientTop       =   450
   ClientWidth     =   5040
   OleObjectBlob   =   "frmPromptTool.frx":0000
   StartUpPosition =   3  'Windows-Standard
End
Attribute VB_Name = "frmPromptTool"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' --- Globale Variable f�r das Modul, um die Prompts zu speichern ---
Private promptsList As VBA.Collection

'------------------------------------------------------------------------------
' Wird ausgef�hrt, wenn das Formular initialisiert wird.
'------------------------------------------------------------------------------
Private Sub UserForm_Initialize()
    Me.Caption = "Prompt Tool (Lade Konfiguration...)"
    lblStatus.Caption = "Lade verf�gbare Modelle und Prompts..."
    DoEvents ' UI aktualisieren

    ' --- SCHRITT 1: Verf�gbare Modelle von der API laden ---
    ' ========================================================
    Dim modelsList As VBA.Collection
    Set modelsList = Modul2.GetAllModels(ApplyFilter:=False) ' Alle Modelle von OWUI laden, gefiltert oder nicht
    
    Me.cboModel.Clear ' Alte Eintr�ge l�schen
    
    If modelsList.Count > 0 Then
        ' ComboBox mit den abgerufenen Modellen f�llen
        Dim modelName As Variant
        For Each modelName In modelsList
            Me.cboModel.AddItem modelName
        Next modelName
        
        ' Versuche, das Standardmodell aus Modul2 auszuw�hlen
        On Error Resume Next ' Zur Sicherheit, falls das Standardmodell nicht existiert
        Me.cboModel.value = Modul2.OWUI_MODEL
        If Err.Number <> 0 Then
            ' Wenn das Standardmodell nicht gefunden wurde, w�hle das erste der Liste
            Me.cboModel.ListIndex = 0
        End If
        On Error GoTo 0
        
    Else
        ' Fallback, wenn keine Modelle geladen werden konnten
        Me.cboModel.AddItem "Keine Modelle gefunden"
        Me.cboModel.ListIndex = 0
        Me.cboModel.Enabled = False
    End If
    
    ' --- SCHRITT 2: Verf�gbare Prompts von der API laden ---
    ' ========================================================
    Set promptsList = Modul2.GetAllPromptCommands()
    
    If promptsList.Count > 0 Then
        ' ComboBox mit den abgerufenen Prompts f�llen
        Dim p As Variant
        For Each p In promptsList
            cboPrompts.AddItem p
        Next p
        cboPrompts.ListIndex = -1 ' Keine Vorauswahl
        lblStatus.Caption = "W�hle einen der " & promptsList.Count & " von OpenWebUI geladenen Prompts oder verfasse einen neuen."
    Else
        lblStatus.Caption = "Konnte keine Prompts laden."
        cboPrompts.AddItem "Keine Prompts gefunden."
        cboPrompts.Enabled = False
    End If
    
    Me.Caption = "Prompt Tool"
End Sub

'------------------------------------------------------------------------------
' NEU: Wird ausgef�hrt, wenn ein Prompt aus der Liste ausgew�hlt wird.
'------------------------------------------------------------------------------
Private Sub cboPrompts_Change()
    If cboPrompts.ListIndex = -1 Then Exit Sub ' Nichts tun, wenn die Auswahl gel�scht wird
    
    ' --- Ben�tigte Variablen deklarieren ---
    Dim selectedCommand As String
    Dim promptContent As String
    Dim modelToSelect As String  ' Variable aus der Logik hinzugef�gt
    
    ' --- Bestehende Logik zum Laden des Prompt-Inhalts ---
    selectedCommand = cboPrompts.value
    lblStatus.Caption = "Lade Inhalt f�r '" & selectedCommand & "'..."
    DoEvents
    
    ' Verwende die bestehende Funktion, um den Inhalt des Prompts abzurufen
    promptContent = Modul2.GetPromptByCommandName(selectedCommand)
    
    ' --- Pr�fen, ob der Inhalt erfolgreich geladen wurde ---
    If promptContent <> "" Then
        ' Den geladenen Prompt im Textfeld anzeigen
        txtPrompt.text = promptContent
        lblStatus.Caption = "Prompt geladen. Bereit zum Senden."
        
        ' 1. Den Modellnamen aus dem geladenen Prompt-Inhalt extrahieren
        modelToSelect = Modul2.ExtractModelName(promptContent)

        ' 2. Die Modell-ComboBox (cboModel) basierend auf dem Ergebnis aktualisieren
        If modelToSelect <> "" Then
            ' Versuche, das extrahierte Modell in der ComboBox zu selektieren
            On Error Resume Next ' Falls das Modell nicht in der Liste existiert
            Me.cboModel.value = modelToSelect
            
            ' Pr�fen, ob ein Fehler aufgetreten ist (Modell nicht gefunden)
            If Err.Number <> 0 Then
                 ' Optional: Fehler behandeln und Standard ausw�hlen
                MsgBox "Modell '" & modelToSelect & "' nicht in der Liste gefunden. Standard wird beibehalten.", vbExclamation
                Me.cboModel.ListIndex = 0 ' W�hle Standard (z.B. erstes Element)
            End If
            On Error GoTo 0 ' Fehlerbehandlung zur�cksetzen
        Else
            ' 3. Fallback: Wenn der Prompt KEINEN {{MODEL}}-Tag hat,
            '    w�hle das in Modul2.OWUI_MODEL definierte Standardmodell aus.
            On Error Resume Next ' Zur Sicherheit, falls das Standardmodell nicht in der Liste existiert
            Me.cboModel.value = Modul2.OWUI_MODEL
            
            ' Wenn das Setzen des Standardmodells fehlschl�gt (z.B. nicht in der Liste),
            ' dann als letzten Ausweg das erste Element der Liste w�hlen.
            If Err.Number <> 0 Then
                Me.cboModel.ListIndex = 0
            End If
            On Error GoTo 0 ' Fehlerbehandlung zur�cksetzen
        End If
        
    Else
        ' Bestehende Logik f�r den Fehlerfall
        txtPrompt.text = "Fehler: Konnte Inhalt f�r '" & selectedCommand & "' nicht laden."
        lblStatus.Caption = "Fehler beim Laden des Prompts."
    End If
End Sub

'------------------------------------------------------------------------------
' Wird ausgef�hrt, wenn der "Senden"-Button geklickt wird.
'------------------------------------------------------------------------------
Private Sub btnSend_Click()
    Dim finalPrompt As String
    Dim model As String
    Dim result As String
    
    model = cboModel.value
    
    If Trim(txtPrompt.text) = "" Then
        MsgBox "Bitte geben Sie einen Prompt ein oder w�hlen Sie einen aus der Liste.", vbExclamation
        Exit Sub
    End If

    ' WICHTIG: Die Platzhalter erst jetzt, direkt vor dem Senden, ersetzen.
    finalPrompt = Modul2.InjectPrompt(txtPrompt.text)
    
    lblStatus.Caption = "Sende Anfrage an " & model & "..."
    Me.Repaint ' UI sofort aktualisieren
    
    ' Funktion aufrufen, um die Antwort direkt ins Word-Dokument zu streamen
    result = Modul2.StreamOWUIToWordWithModel(finalPrompt, model)

    lblStatus.Caption = "Antwort wurde eingef�gt."
End Sub

'------------------------------------------------------------------------------
' Schliesst das Formular
'------------------------------------------------------------------------------
Private Sub btnClose_Click()
    Unload Me
End Sub


