/*
 *$Id: hcwindow.prg 2248 2014-04-30 10:13:48Z alkresin $
 *
 * HWGUI - Harbour Win32 GUI library source code:
 * HCustomWindow class
 *
 * Copyright 2004 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "windows.ch"
#include "hbclass.ch"
#include "guilib.ch"
#include "error.ch"

STATIC aCustomEvents := { ;
      { WM_PAINT, WM_COMMAND, WM_SIZE, WM_DESTROY }, ;
      { ;
      { |o, w|iif( o:bPaint != Nil, Eval( o:bPaint,o,w ), - 1 ) }, ;
      { |o, w, l|onCommand( o, w ) },                ;
      { |o, w, l|onSize( o, w, l ) },                ;
      { |o|onDestroy( o ) }                          ;
      } ;
      }

CLASS HObject

   DATA cargo
ENDCLASS

CLASS HCustomWindow INHERIT HObject

   CLASS VAR oDefaultParent SHARED
   DATA handle  INIT 0
   DATA oParent
   DATA title
   DATA TYPE
   DATA nTop, nLeft, nWidth, nHeight
   DATA tcolor, bcolor, brush
   DATA style
   DATA extStyle  INIT 0
   DATA lHide INIT .F.
   DATA oFont
   DATA aEvents   INIT {}
   DATA aNotify   INIT {}
   DATA aControls INIT {}
   DATA bInit
   DATA bDestroy
   DATA bSize
   DATA bPaint
   DATA bGetFocus
   DATA bLostFocus
   DATA bOther
   DATA HelpId   INIT 0

   METHOD AddControl( oCtrl ) INLINE AAdd( ::aControls, oCtrl )
   METHOD DelControl( oCtrl )
   METHOD AddEvent( nEvent, nId, bAction ) ;
      INLINE AAdd( ::aEvents, { nEvent, nId, bAction } )
   METHOD FindControl( nId, nHandle )
   METHOD Hide() INLINE ( ::lHide := .T. , hwg_Hidewindow( ::handle ) )
   METHOD Show() INLINE ( ::lHide := .F. , hwg_Showwindow( ::handle ) )
   METHOD Move( x1, y1, width, height )
   METHOD Setcolor( tcolor, bcolor, lRepaint )
   METHOD onEvent( msg, wParam, lParam )
   METHOD End()
   ERROR HANDLER OnError()

ENDCLASS

METHOD FindControl( nId, nHandle ) CLASS HCustomWindow
   LOCAL i := iif( nId != Nil, Ascan( ::aControls,{ |o|o:id == nId } ), ;
      Ascan( ::aControls, { |o|o:handle == nHandle } ) )

   RETURN iif( i == 0, Nil, ::aControls[i] )

METHOD DelControl( oCtrl ) CLASS HCustomWindow
   LOCAL id := oCtrl:id, h
   LOCAL i := Ascan( ::aControls, { |o|o == oCtrl } )

   IF oCtrl:ClassName() == "HPANEL"
      hwg_Destroypanel( oCtrl:handle )
   ELSE
      hwg_DestroyWindow( oCtrl:handle )
   ENDIF
   IF i != 0
      ADel( ::aControls, i )
      ASize( ::aControls, Len( ::aControls ) - 1 )
   ENDIF
   h := 0
   FOR i := Len( ::aEvents ) TO 1 STEP - 1
      IF ::aEvents[i,2] == id
         ADel( ::aEvents, i )
         h ++
      ENDIF
   NEXT
   IF h > 0
      ASize( ::aEvents, Len( ::aEvents ) - h )
   ENDIF
   h := 0
   FOR i := Len( ::aNotify ) TO 1 STEP - 1
      IF ::aNotify[i,2] == id
         ADel( ::aNotify, i )
         h ++
      ENDIF
   NEXT
   IF h > 0
      ASize( ::aNotify, Len( ::aNotify ) - h )
   ENDIF

   RETURN Nil

METHOD Move( x1, y1, width, height )  CLASS HCustomWindow

   IF x1 != Nil
      ::nLeft := x1
   ENDIF
   IF y1 != Nil
      ::nTop  := y1
   ENDIF
   IF width != Nil
      ::nWidth := width
   ENDIF
   IF height != Nil
      ::nHeight := height
   ENDIF
   hwg_Movewindow( ::handle, ::nLeft, ::nTop, ::nWidth, ::nHeight )

   RETURN Nil

METHOD Setcolor( tcolor, bcolor, lRepaint ) CLASS HCustomWindow

   IF tcolor != Nil
      ::tcolor  := tcolor
      IF !Empty( ::handle )
         hwg_Setfgcolor( ::handle, ::tcolor )
      ENDIF
   ENDIF

   IF bcolor != Nil
      ::bcolor  := bcolor
      IF !Empty( ::handle )
         hwg_Setbgcolor( ::handle, ::bcolor )
      ENDIF
      IF ::brush != Nil
         ::brush:Release()
      ENDIF
      ::brush := HBrush():Add( bcolor )
   ENDIF

   IF lRepaint != Nil .AND. lRepaint
      hwg_Redrawwindow( ::handle, RDW_ERASE + RDW_INVALIDATE )
   ENDIF

   RETURN Nil

METHOD onEvent( msg, wParam, lParam ) CLASS HCustomWindow
   LOCAL i

   // hwg_WriteLog( "== "+::Classname()+Str(msg)+Iif(wParam!=Nil,Str(wParam),"Nil")+Iif(lParam!=Nil,Str(lParam),"Nil") )
   IF ( i := Ascan( aCustomEvents[1],msg ) ) != 0
      RETURN Eval( aCustomEvents[2,i], Self, wParam, lParam )
   ELSEIF ::bOther != Nil
      RETURN Eval( ::bOther, Self, msg, wParam, lParam )
   ENDIF

   RETURN 0

METHOD End()  CLASS HCustomWindow
   LOCAL aControls := ::aControls
   LOCAL i, nLen := Len( aControls )

   FOR i := 1 TO nLen
      aControls[i]:End()
   NEXT

   hwg_ReleaseObject( ::handle )

   RETURN Nil

METHOD OnError() CLASS HCustomWindow

   LOCAL cMsg := __GetMessage()
   LOCAL oError
   LOCAL aControls := ::aControls, oItem

   FOR EACH oItem IN aControls
      IF !Empty( oItem:objname ) .AND. oItem:objname == cMsg
         RETURN oItem
      ENDIF
   NEXT

   oError := ErrorNew()
   oError:severity    := ES_ERROR
   oError:genCode     := EG_LIMIT
   oError:subSystem   := "HCUSTOMWINDOW"
   oError:subCode     := 0
   oError:description := "Invalid class member"
   oError:canRetry    := .F.
   oError:canDefault  := .F.
   oError:fileName    := ""
   oError:osCode      := 0

   Eval( ErrorBlock(), oError )
   __errInHandler()

   RETURN NIL

STATIC FUNCTION onDestroy( oWnd )

   oWnd:End()

   RETURN 0

STATIC FUNCTION onCommand( oWnd, wParam )
   LOCAL iItem, iParHigh := hwg_Hiword( wParam ), iParLow := hwg_Loword( wParam )

   IF oWnd:aEvents != Nil .AND. ;
         ( iItem := Ascan( oWnd:aEvents, { |a|a[1] == iParHigh .AND. a[2] == iParLow } ) ) > 0
      Eval( oWnd:aEvents[ iItem,3 ], oWnd, iParLow )
   ENDIF

   RETURN 1

STATIC FUNCTION onSize( oWnd, wParam, lParam )
   LOCAL aControls := oWnd:aControls, oItem, x, y

   FOR EACH oItem in aControls
      IF oItem:bSize != Nil
         IF wParam != 0
            x := wParam
            y := lParam
         ELSE
            x := hwg_Loword( lParam )
            y := hwg_Hiword( lParam )
         ENDIF
         Eval( oItem:bSize, oItem, x, y )
         onSize( oItem, oItem:nWidth, oItem:nHeight )
      ENDIF
   NEXT

   RETURN 0

FUNCTION hwg_onTrackScroll( oWnd, wParam, lParam )

   LOCAL oCtrl := oWnd:FindControl( , lParam ), msg

   IF oCtrl != Nil
      msg := hwg_Loword ( wParam )
      IF msg == TB_ENDTRACK
         IF ISBLOCK( oCtrl:bChange )
            Eval( oCtrl:bChange, oCtrl )
            RETURN 0
         ENDIF
      ELSEIF msg == TB_THUMBTRACK .OR. msg == TB_PAGEUP .OR. msg == TB_PAGEDOWN
         IF ISBLOCK( oCtrl:bThumbDrag )
            Eval( oCtrl:bThumbDrag, oCtrl )
            RETURN 0
         ENDIF
      ENDIF
   ENDIF

   RETURN 0

   INIT PROCEDURE HWGINIT

   hwg_gtk_init()
   Hwg_InitProc()
   hwg_ErrSys()

   RETURN

   EXIT PROCEDURE Hwg_ExitProcedure
   Hwg_ExitProc()

   RETURN
