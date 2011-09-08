'
' Change History :
'  BaH 26/05/2009 - Added multi-process (threading) support.
'                   Improved custom variable overriding.
'  BaH 18/05/2009 - Added Universal support (Mac) with -i parameter.
'                   Added cross-compile support with -l win32.
'  BaH 28/09/2007 - Added custom appstub compiles using -b parameter.
'                   Synched with current bmk source.
'
Strict

Framework brl.basic

Import "bmk_make.bmx"
Import "bmk_zap.bmx"
Import "bmk_bb2bmx.bmx"

?MacOS
Incbin "macos.icns"
?

If AppArgs.length<2 CmdError "Not enough parameters", True

Local cmd$=AppArgs[1],args$[]

args=ParseConfigArgs( AppArgs[2..] )

' preload the default options
RunCommand("default_cc_opts", Null)

' load any global custom options (in BlitzMax/bin)
LoadBMK(AppDir + "/custom.bmk")

CreateDir BlitzMaxPath()+"/tmp"

Select cmd.ToLower()
Case "makeapp"
	SetConfigMung
	MakeApplication args,False
Case "makelib"
	SetConfigMung
	MakeApplication args,True
Case "makemods"
	If opt_debug Or opt_release
		SetConfigMung
		MakeModules args
		If opt_universal
			SetConfigMung
			processor.ToggleCPU()
			MakeModules args
			processor.ToggleCPU()
		End If
	
	Else
		opt_debug=True
		opt_release=False
		SetConfigMung
		MakeModules args
		If opt_universal
			SetConfigMung
			processor.ToggleCPU()
			MakeModules args
			processor.ToggleCPU()
		End If
		opt_debug=False
		opt_release=True
		SetConfigMung
		MakeModules args
		If opt_universal
			SetConfigMung
			processor.ToggleCPU()
			MakeModules args
			processor.ToggleCPU()
		End If
	EndIf
Case "cleanmods"
	CleanModules args
Case "zapmod"
	ZapModule args
Case "unzapmod"
	UnzapModule args
Case "listmods"
	ListModules args
Case "modstatus"
	ModuleStatus args
Case "syncmods" 
	SyncModules args
Case "convertbb"
	ConvertBB args
Case "ranlibdir"
	RanlibDir args
Case "-v"
	VersionInfo
Default
	CmdError "Unknown operation '" + cmd.ToLower() + "'"
End Select

Function SetConfigMung()
	If opt_release
		opt_debug=False
		opt_configmung="release"
		If opt_threaded opt_configmung:+".mt"
		opt_configmung="."+opt_configmung+"."+processor.Platform()+"."'+opt_arch
	Else
		opt_debug=True
		opt_release=False
		opt_configmung="debug"
		If opt_threaded opt_configmung:+".mt"
		opt_configmung="."+opt_configmung+"."+processor.Platform()+"."'+opt_arch
	EndIf
End Function

Function SetModfilter( t$ )

	opt_modfilter=t.ToLower()

	If opt_modfilter="*"
		opt_modfilter=""
	Else If opt_modfilter[opt_modfilter.length-1]<>"." 
		opt_modfilter:+"."
	EndIf
	
End Function

Function MakeModules( args$[] )

	If args.length>1 CmdError "Expecting only 1 argument for makemods"
	
	If args.length SetModfilter args[0] Else opt_modfilter=""
	
	Local mods:TList=EnumModules()
	
	BeginMake

	MakeMod "brl.blitz"
	
	For Local name$=EachIn mods
		MakeMod name
	Next
	
End Function

Function CleanModules( args$[] )

	If args.length>1 CmdError "Expecting only 1 argument for cleanmods"
	
	If args.length SetModfilter args[0] Else opt_modfilter=""
	
	Local mods:TList=EnumModules()

	Local name$
	For name=EachIn mods
	
		If (name+".").Find(opt_modfilter)<>0 Continue
		
		Print "Cleaning:"+name

		Local path$=ModulePath(name)
		
		DeleteDir path+"/.bmx",True
		
		If Not opt_kill Continue
		
		For Local f$=EachIn LoadDir( path )
		
			Local p$=path+"/"+f
			Select FileType(p)
			Case FILETYPE_DIR
				If f<>"doc"
					DeleteDir p,True
				EndIf
			Case FILETYPE_FILE
				Select ExtractExt(f).tolower()
				Case "i","a","txt","htm","html"
					'nop
				Default
					DeleteFile p
				End Select
			End Select

		Next
	Next

End Function

Function MakeApplication( args$[],makelib )

	If opt_execute
		If Len(args)=0 CmdError "Execute requires at least 1 argument"
	Else
		If Len(args)<>1 CmdError "Expecting only 1 argument for makeapp"
	EndIf

	Local Main$=RealPath( args[0] )
	
	Select ExtractExt(Main).ToLower()
	Case ""
		Main:+".bmx"
	Case "c","cpp","cxx","mm","bmx"
	Default
		Throw "Unrecognized app source file type:"+ExtractExt(Main)
	End Select

	If FileType(Main)<>FILETYPE_FILE Throw "Unable to open source file '"+Main+"'"
	
	If Not opt_outfile opt_outfile=StripExt( Main )

	' set some useful global variables
	globals.SetVar("BUILDPATH", ExtractDir(opt_outfile))
	globals.SetVar("EXEPATH", ExtractDir(opt_outfile))
	globals.SetVar("OUTFILE", StripDir(StripExt(opt_outfile)))
	
	If processor.Platform() = "win32" Then
		If makelib
			If ExtractExt(opt_outfile).ToLower()<>"dll" opt_outfile:+".dll"
		Else
			If ExtractExt(opt_outfile).ToLower()<>"exe" opt_outfile:+".exe"
		EndIf
	EndIf

	If processor.Platform() = "macos" Then
		If opt_apptype="gui"
	
			Local appId$=StripDir( opt_outfile )
	
			Local exeDir$=opt_outfile+".app",d$,t:TStream
	
			d=exeDir+"/Contents/MacOS"
			Select FileType( d )
			Case FILETYPE_NONE
				CreateDir d,True
				If FileType( d )<>FILETYPE_DIR
					Throw "Unable to create application directory"
				EndIf
			Case FILETYPE_FILE
				Throw "Unable to create application directory"
			Case FILETYPE_DIR
			End Select
			
			d=exeDir+"/Contents/Resources"
			Select FileType( d )
			Case FILETYPE_NONE
				CreateDir d
				If FileType( d )<>FILETYPE_DIR
					Throw "Unable to create resources directory"
				EndIf
			Case FILETYPE_FILE
				Throw "Unable to create resources directory"
			Case FILETYPE_DIR
			End Select
	
			t=WriteStream( exeDir+"/Contents/Info.plist" )
			If Not t Throw "Unable to create Info.plist"
			t.WriteLine "<?xml version=~q1.0~q encoding=~qUTF-8~q?>"
			t.WriteLine "<!DOCTYPE plist PUBLIC ~q-//Apple Computer//DTD PLIST 1.0//EN~q ~qhttp://www.apple.com/DTDs/PropertyList-1.0.dtd~q>"
			t.WriteLine "<plist version=~q1.0~q>"
			t.WriteLine "<dict>"
			t.WriteLine "~t<key>CFBundleExecutable</key>"
			t.WriteLine "~t<string>"+appId+"</string>"
			t.WriteLine "~t<key>CFBundleIconFile</key>"
			t.WriteLine "~t<string>"+appId+"</string>"
			t.WriteLine "~t<key>CFBundlePackageType</key>"
			t.WriteLine "~t<string>APPL</string>"
			t.WriteLine "</dict>"
			t.WriteLine "</plist>"
			t.Close
	
			t=WriteStream( exeDir+"/Contents/Resources/"+appId+".icns" )
			If Not t Throw "Unable to create icons"
			Local in:TStream=ReadStream( "incbin::macos.icns" )
			CopyStream in,t
			in.Close
			t.Close
			
			opt_outfile=exeDir+"/Contents/MacOS/"+appId
			
			' Mac GUI exepath is in the bundle...
			globals.SetVar("EXEPATH", ExtractDir(opt_outfile))
			
		EndIf
	End If
	
	BeginMake
	
	MakeApp Main,makelib

	If opt_universal

		Local previousOutfile:String = opt_outfile
		processor.ToggleCPU()
		opt_outfile :+ "." + processor.CPU()
		BeginMake
		MakeApp Main,makelib
		processor.ToggleCPU()
		
		MergeApp opt_outfile, previousOutfile
		
		opt_outfile = previousOutfile
	End If
	
	If opt_execute

		Print "Executing:"+StripDir( opt_outfile )

		Local cmd$=CQuote( opt_outfile )
		For Local i=1 Until args.length
			cmd:+" "+CQuote( args[i] )
		Next
		
		Sys cmd
		
	EndIf

End Function

Function ZapModule( args$[] )
	If Len(args)<>2 CmdError "Both module name and outfile required"

	Local modname$=args[0].ToLower()
	Local outfile$=RealPath( args[1] )

	Local stream:TStream=WriteStream( outfile )
	If Not stream Throw "Unable to open output file"
	
	ZapMod modname,stream
	
	stream.Close
End Function

Function UnzapModule( args$[] )
	If Len(args)<>1 CmdError "Expecting 1 argument for unzapmod"
	
	Local infile$=args[0]
	
	Local stream:TStream=ReadStream( infile )
	If Not stream Throw "Unable to open input file"
	
	UnzapMod stream
	
	stream.Close
End Function

Function ListModules( args$[],modid$="" )
	If Len(args)<>0 CmdError
	
	Throw "Todo!"

End Function

Function ModuleStatus( args$[] )
	If Len(args)<>1 CmdError
	
	ListModules Null,args[0]

End Function

Function SyncModules( args$[] )
	If args.length CmdError
	
	If Sys( BlitzMaxPath()+"/bin/syncmods" ) Throw "SyncMods error"
	
End Function

Function RanlibDir( args$[] )
	If args.length<>1 CmdError "Expecting 1 argument for ranlibdir"
	
	Ranlib args[0]

End Function

