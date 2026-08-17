' Remake Windows desktop shortcuts for the updated AI Godot Studio
' and Chrome Cannon Glass 1.0.0 final package.
' Double-click this file (or run Make-DesktopShortcut.ps1).

Option Explicit
Dim fso, sh, scriptDir, repo, desktop, godot, sc, names, i, p, downloads, folder, file

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
repo = fso.GetParentFolderName(scriptDir)
desktop = sh.SpecialFolders("Desktop")
downloads = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\Downloads"

If Not fso.FileExists(repo & "\project.godot") Then
  MsgBox "project.godot not found at:" & vbCrLf & repo, vbCritical, "Desktop shortcut"
  WScript.Quit 1
End If

godot = ""
If fso.FileExists(downloads & "\Godot_v4.7.1-stable_win64.exe") Then
  godot = downloads & "\Godot_v4.7.1-stable_win64.exe"
ElseIf fso.FileExists("C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe") Then
  godot = "C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe"
ElseIf fso.FolderExists(downloads) Then
  Set folder = fso.GetFolder(downloads)
  For Each file In folder.Files
    If LCase(fso.GetExtensionName(file.Name)) = "exe" Then
      If Left(LCase(file.Name), 8) = "godot_v4" Then
        If InStr(LCase(file.Name), "console") = 0 Then
          godot = file.Path
          Exit For
        End If
      End If
    End If
  Next
End If

names = Array( _
  "AI Godot Studio.lnk", _
  "Chrome Cannon Glass.lnk", _
  "ChromeCannonGlass.lnk", _
  "ai-godot-studio.lnk", _
  "Launch-AIGodotStudio.bat", _
  "Open-ChromeCannonGlass.bat" _
)
For i = 0 To UBound(names)
  p = desktop & "\" & names(i)
  If fso.FileExists(p) Then fso.DeleteFile p, True
Next

fso.CopyFile scriptDir & "\Launch-AIGodotStudio.bat", desktop & "\Launch-AIGodotStudio.bat", True
fso.CopyFile scriptDir & "\Open-ChromeCannonGlass.bat", desktop & "\Open-ChromeCannonGlass.bat", True
If fso.FileExists(scriptDir & "\Chrome Cannon Glass 1.0.0 final.url") Then
  fso.CopyFile scriptDir & "\Chrome Cannon Glass 1.0.0 final.url", desktop & "\Chrome Cannon Glass 1.0.0 final.url", True
End If

If godot <> "" Then
  Set sc = sh.CreateShortcut(desktop & "\AI Godot Studio.lnk")
  sc.TargetPath = godot
  sc.Arguments = "--path """ & repo & """"
  sc.WorkingDirectory = repo
  sc.WindowStyle = 1
  sc.Description = "AI Godot Studio 2.0 — updated (Chrome Cannon Glass 1.0.0 final)"
  sc.IconLocation = godot & ",0"
  sc.Save
End If

Set sc = sh.CreateShortcut(desktop & "\Chrome Cannon Glass.lnk")
If fso.FolderExists(repo & "\codea\dist\ChromeCannonGlass.codea") Then
  sc.TargetPath = "explorer.exe"
  sc.Arguments = """" & repo & "\codea\dist\ChromeCannonGlass.codea"""
Else
  sc.TargetPath = desktop & "\Open-ChromeCannonGlass.bat"
  sc.Arguments = ""
End If
sc.WorkingDirectory = repo & "\codea\dist"
sc.WindowStyle = 1
sc.Description = "Chrome Cannon Glass 1.0.0 final — Codea package"
sc.Save

MsgBox "Desktop shortcuts remade:" & vbCrLf & vbCrLf & _
  "AI Godot Studio.lnk -> " & godot & vbCrLf & _
  "Chrome Cannon Glass.lnk -> 1.0.0 final package" & vbCrLf & vbCrLf & _
  "Project: " & repo, vbInformation, "Desktop shortcut"
