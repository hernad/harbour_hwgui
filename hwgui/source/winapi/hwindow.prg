/*
 *$Id: hwindow.prg 2293 2014-10-17 10:25:43Z alkresin $
 *
 * HWGUI - Harbour Win32 GUI library source code:
 * HWindow class
 *
 * Copyright 2002 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "windows.ch"
#include "hbclass.ch"
#include "guilib.ch"

#define  FIRST_MDICHILD_ID     501
#define  MAX_MDICHILD_WINDOWS   18
#define  WM_NOTIFYICON         WM_USER+1000
#define  ID_NOTIFYICON           1

FUNCTION hwg_onWndSize( oWnd, wParam, lParam )

   LOCAL aCoors := hwg_Getwindowrect( oWnd:handle )

   wParam := hwg_PtrToUlong( wParam )
   IF oWnd:oEmbedded != Nil
      oWnd:oEmbedded:Resize( hwg_Loword( lParam ), hwg_Hiword( lParam ) )
   ENDIF

   IF wParam != 1
      IF oWnd:nScrollBars > - 1 .AND. oWnd:lAutoScroll .AND. !Empty( oWnd:Type )
         IF Empty( oWnd:rect )
            oWnd:rect := hwg_Getclientrect( oWnd:handle )
            AEval( oWnd:aControls, {|o| oWnd:ncurHeight := Max( o:nTop + o:nHeight + VERT_PTS * 4, oWnd:ncurHeight ) } )
            AEval( oWnd:aControls, {|o| oWnd:ncurWidth := Max( o:nLeft + o:nWidth  + HORZ_PTS * 4, oWnd:ncurWidth ) } )
         ENDIF
         oWnd:ResetScrollbars()
         oWnd:SetupScrollbars()
      ENDIF
      onAnchor( oWnd, oWnd:nWidth, oWnd:nHeight, aCoors[3]-aCoors[1], aCoors[4]-aCoors[2] )
   ENDIF
   oWnd:Super:onEvent( WM_SIZE, wParam, lParam )

   IF wParam != 1
      oWnd:nWidth  := aCoors[3] - aCoors[1]
      oWnd:nHeight := aCoors[4] - aCoors[2]
   ENDIF

   IF HB_ISBLOCK( oWnd:bSize )
      Eval( oWnd:bSize, oWnd, hwg_Loword( lParam ), hwg_Hiword( lParam ) )
   ENDIF
   IF oWnd:type == WND_MDI .AND. Len( HWindow():aWindows ) > 1
      aCoors := hwg_Getclientrect( oWnd:handle )
      hwg_Movewindow( HWindow():aWindows[2]:handle, oWnd:aOffset[1], oWnd:aOffset[2], aCoors[3] - oWnd:aOffset[1] - oWnd:aOffset[3], aCoors[4] - oWnd:aOffset[2] - oWnd:aOffset[4] )
      RETURN 0
   ENDIF

   RETURN Iif( !Empty(oWnd:type) .AND. oWnd:type >= WND_DLG_RESOURCE, 0, - 1 )

STATIC FUNCTION onAnchor( oWnd, wold, hold, wnew, hnew )
LOCAL aControls := oWnd:aControls, oItem, w, h

   FOR EACH oItem IN aControls
      IF oItem:Anchor > 0
         w := oItem:nWidth
         h := oItem:nHeight
         oItem:onAnchor( wold, hold, wnew, hnew )
         onAnchor( oItem, w, h, oItem:nWidth, oItem:nHeight )
      ENDIF
   NEXT
   RETURN Nil

STATIC FUNCTION hwg_onEnterIdle( oDlg, wParam, lParam )
   LOCAL oItem
   IF ( Empty( wParam ) .AND. ( oItem := Atail( HDialog():aModalDialogs ) ) != Nil ;
         .AND. oItem:handle == lParam )
      oDlg := oItem
   ENDIF
   IF __ObjHasMsg( oDlg, "BACTIVATE" )
      IF oDlg:bActivate != Nil
         Eval( oDlg:bActivate, oDlg )
         oDlg:bActivate := Nil
      ENDIF
   ENDIF

   RETURN 0

FUNCTION hwg_onDestroy( oWnd )
Local i, nHandle := oWnd:handle

   IF oWnd:oEmbedded != Nil
      oWnd:oEmbedded:End()
      oWnd:oEmbedded := Nil
   ENDIF

   IF ( i := Ascan( HTimer():aTimers,{|o|hwg_Isptreq( o:oParent:handle,nHandle )} ) ) != 0
      HTimer():aTimers[i]:End()
   ENDIF

   oWnd:Super:onEvent( WM_DESTROY )
   oWnd:DelItem( oWnd )

   RETURN 0

CLASS HWindow INHERIT HCustomWindow, HScrollArea

   CLASS VAR aWindows    SHARED INIT {}
   CLASS VAR szAppName   SHARED INIT "HwGUI_App"
   CLASS VAR aKeysGlobal SHARED INIT {}

   DATA menu, oPopup, hAccel
   DATA oIcon, oBmp
   DATA lUpdated INIT .F.     // TRUE, if any GET is changed
   DATA lClipper INIT .F.
   DATA GetList  INIT {}      // The array of GET items in the dialog
   DATA KeyList  INIT {}      // The array of keys ( as Clipper's SET KEY )
   DATA nLastKey INIT 0
   DATA bCloseQuery
   DATA bActivate

   DATA aOffset
   DATA oEmbedded
   DATA bScroll

   METHOD New( Icon, clr, nStyle, x, y, width, height, cTitle, cMenu, oFont, ;
      bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther, cAppName, oBmp, cHelp, ;
      nHelpId, bCloseQuery, bColor )
   METHOD AddItem( oWnd )
   METHOD DelItem( oWnd )
   METHOD FindWindow( hWnd )
   METHOD GetMain()
   METHOD EvalKeyList( nKey, bPressed )
   METHOD Center()   INLINE Hwg_CenterWindow( ::handle )
   METHOD Restore()  INLINE hwg_Sendmessage( ::handle, WM_SYSCOMMAND, SC_RESTORE, 0 )
   METHOD Maximize() INLINE hwg_Sendmessage( ::handle, WM_SYSCOMMAND, SC_MAXIMIZE, 0 )
   METHOD Minimize() INLINE hwg_Sendmessage( ::handle, WM_SYSCOMMAND, SC_MINIMIZE, 0 )
   METHOD Close()    INLINE hwg_Sendmessage( ::handle, WM_SYSCOMMAND, SC_CLOSE, 0 )
   METHOD SetTitle( cTitle ) INLINE hwg_Setwindowtext( ::handle, ::title := cTitle )

ENDCLASS

METHOD New( oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, oFont, ;
      bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther, ;
      cAppName, oBmp, cHelp, nHelpId, bCloseQuery, bColor ) CLASS HWindow

   ::oDefaultParent := Self
   ::title    := cTitle
   ::style    := Iif( nStyle == Nil, 0, nStyle )
   ::oIcon    := oIcon
   ::oBmp     := oBmp
   ::nTop     := Iif( y == Nil, 0, y )
   ::nLeft    := if( x == Nil, 0, x )
   ::nWidth   := Iif( width == Nil, 0, width )
   ::nHeight  := Iif( height == Nil, 0, height )
   ::oFont    := oFont
   ::bInit    := bInit
   ::bDestroy := bExit
   ::bSize    := bSize
   ::bPaint   := bPaint
   ::bGetFocus  := bGFocus
   ::bLostFocus := bLFocus
   ::bOther     := bOther
   ::bCloseQuery := bCloseQuery

   IF bColor != Nil
      ::brush := HBrush():Add( bColor )
   ENDIF
   IF cAppName != Nil
      ::szAppName := cAppName
   ENDIF
   IF nHelpId != nil
      ::HelpId := nHelpId
   END

   ::aOffset := Array( 4 )
   AFill( ::aOffset, 0 )

   IF Hwg_Bitand( ::style,WS_HSCROLL ) > 0
      ::nScrollBars ++
   ENDIF
   IF  Hwg_Bitand( ::style,WS_VSCROLL ) > 0
      ::nScrollBars += 2
   ENDIF

   ::AddItem( Self )

   RETURN Self

METHOD AddItem( oWnd ) CLASS HWindow

   AAdd( ::aWindows, oWnd )

   RETURN Nil

METHOD DelItem( oWnd ) CLASS HWindow

   LOCAL i, h := oWnd:handle

   IF ( i := Ascan( ::aWindows,{ |o|hwg_Isptreq( o:handle,h) } ) ) > 0
      ADel( ::aWindows, i )
      ASize( ::aWindows, Len( ::aWindows ) - 1 )
   ENDIF

   RETURN Nil

METHOD FindWindow( hWnd ) CLASS HWindow

   LOCAL i := Ascan( ::aWindows, { |o|hwg_Isptreq( o:handle,hWnd) } )

   RETURN Iif( i == 0, Nil, ::aWindows[i] )

METHOD GetMain CLASS HWindow

   RETURN Iif( Len( ::aWindows ) > 0,              ;
      Iif( ::aWindows[1]:type == WND_MAIN, ;
      ::aWindows[1],                  ;
      Iif( Len( ::aWindows ) > 1, ::aWindows[2], Nil ) ), Nil )

METHOD EvalKeyList( nKey, bPressed ) CLASS HWindow
   LOCAL cKeyb, nctrl, nPos

   cKeyb := hwg_Getkeyboardstate()
   nctrl := Iif( Asc( SubStr(cKeyb,VK_CONTROL + 1,1 ) ) >= 128, FCONTROL, Iif( Asc(SubStr(cKeyb,VK_SHIFT + 1,1 ) ) >= 128,FSHIFT,0 ) )

   IF !Empty( ::KeyList )
      IF ( nPos := Ascan( ::KeyList,{ |a|a[1] == nctrl .AND. a[2] == nKey } ) ) > 0
         Eval( ::KeyList[ nPos,3 ], ::FindControl( ,hwg_Getfocus() ) )
         RETURN .T.
      ENDIF
   ENDIF
   IF !Empty( ::aKeysGlobal )
      IF ( nPos := Ascan( ::aKeysGlobal,{ |a|a[1] == nctrl .AND. a[2] == nKey } ) ) > 0
         Eval( ::aKeysGlobal[ nPos,3 ], ::FindControl( ,hwg_Getfocus() ) )
      ENDIF
   ENDIF

   RETURN .T.

CLASS HMainWindow INHERIT HWindow

   CLASS VAR aMessages INIT { ;
      { WM_COMMAND, WM_ERASEBKGND, WM_MOVE, WM_SIZE, WM_SYSCOMMAND, ;
      WM_NOTIFYICON, WM_ENTERIDLE, WM_ACTIVATEAPP, WM_CLOSE, WM_DESTROY, WM_ENDSESSION }, ;
      { ;
      {|o,w,l|onCommand( o, w, l ) },       ;
      {|o,w|onEraseBk( o, w ) },            ;
      {|o|onMove( o ) },                    ;
      {|o,w,l|hwg_onWndSize( o, w, l ) },   ;
      {|o,w|onSysCommand( o, w ) },         ;
      {|o,w,l|onNotifyIcon( o, w, l ) },    ;
      {|o,w,l|hwg_onEnterIdle( o, w, l ) }, ;
      {|o,w,l|hwg_onEnterIdle( o, w, l ) }, ;
      {|o|onCloseQuery( o ) },              ;
      {|o|hwg_onDestroy( o ) },             ;
      {|o,w|onEndSession( o, w ) }          ;
      } ;
      }
   DATA   nMenuPos
   DATA oNotifyIcon, bNotify, oNotifyMenu
   DATA lTray INIT .F.

   METHOD New( lType, oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, nPos,   ;
      oFont, bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther, ;
      cAppName, oBmp, cHelp, nHelpId, bCloseQuery, bColor, nExclude )
   METHOD Activate( lShow, lMaximized, lMinimized, bActivate )
   METHOD onEvent( msg, wParam, lParam )
   METHOD InitTray( oNotifyIcon, bNotify, oNotifyMenu, cTooltip )
   METHOD GetMdiActive()  INLINE ::FindWindow( hwg_Sendmessptr( ::GetMain():handle, WM_MDIGETACTIVE,0,0 ) )

ENDCLASS

METHOD New( lType, oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, nPos,   ;
      oFont, bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther, ;
      cAppName, oBmp, cHelp, nHelpId, bCloseQuery, bColor, nExclude ) CLASS HMainWindow
   LOCAL hbrush

   ::Super:New( oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, oFont, ;
      bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther,  ;
      cAppName, oBmp, cHelp, nHelpId, bCloseQuery, bColor )
   ::type := lType

   hbrush := IIf( ::brush != Nil, ::brush:handle, clr )

   IF lType == WND_MDI

      ::nMenuPos := nPos
      ::handle := Hwg_InitMdiWindow( Self, ::szAppName, cTitle, cMenu,  ;
         Iif( oIcon != Nil, oIcon:handle, Nil ), hbrush, ;
         nStyle, ::nLeft, ::nTop, ::nWidth, ::nHeight )

   ELSEIF lType == WND_MAIN

      ::handle := Hwg_InitMainWindow( Self, ::szAppName, cTitle, cMenu, ;
         Iif( oIcon != Nil, oIcon:handle, Nil ), Iif( oBmp != Nil, - 1, hbrush ), ;
         ::Style, Iif( nExclude==Nil, 0, nExclude ), ::nLeft, ;
         ::nTop, ::nWidth, ::nHeight )

      IF cHelp != NIL
         hwg_SetHelpFileName( cHelp )
      ENDIF

   ENDIF
   IF ::bInit != Nil
      Eval( ::bInit, Self )
   ENDIF

   RETURN Self

METHOD Activate( lShow, lMaximized, lMinimized, lCentered, bActivate ) CLASS HMainWindow

   LOCAL oWndClient, handle

   IF bActivate != Nil
      ::bActivate := bActivate
   ENDIF

   hwg_CreateGetList( Self )

   IF ::type == WND_MDI

      oWndClient := HWindow():New( , , , ::style, ::title, , ::bInit, ::bDestroy, ::bSize, ;
         ::bPaint, ::bGetFocus, ::bLostFocus, ::bOther )
      handle := Hwg_InitClientWindow( oWndClient, ::nMenuPos, ::nLeft, ::nTop + 60, ::nWidth, ::nHeight )
      oWndClient:handle = handle

      IF !Empty( lCentered )
         ::Center()
      ENDIF
      Hwg_ActivateMdiWindow( ( lShow == Nil .OR. lShow ), ::hAccel, lMaximized, lMinimized )

   ELSEIF ::type == WND_MAIN

      IF !Empty( lCentered )
         ::Center()
      ENDIF
      Hwg_ActivateMainWindow( ( lShow == Nil .OR. lShow ), ::hAccel, lMaximized, lMinimized )
   ENDIF

   RETURN Nil

METHOD onEvent( msg, wParam, lParam )  CLASS HMainWindow

   LOCAL i

   // hwg_writelog( str(msg) + str(wParam) + str(lParam) )
   IF ( i := Ascan( ::aMessages[1],msg ) ) != 0
      RETURN Eval( ::aMessages[2,i], Self, wParam, lParam )
   ELSE
      IF msg == WM_HSCROLL .OR. msg == WM_VSCROLL .OR. msg == WM_MOUSEWHEEL
         IF ::nScrollBars != -1
             hwg_ScrollHV( Self,msg,wParam,lParam )
         ENDIF
         hwg_onTrackScroll( Self, msg, wParam, lParam )
      ENDIF
      Return ::Super:onEvent( msg, wParam, lParam )
   ENDIF

   Return - 1

METHOD InitTray( oNotifyIcon, bNotify, oNotifyMenu, cTooltip ) CLASS HMainWindow

   ::bNotify     := bNotify
   ::oNotifyMenu := oNotifyMenu
   ::oNotifyIcon := oNotifyIcon
   hwg_Shellnotifyicon( .T. , ::handle, oNotifyIcon:handle, cTooltip )
   ::lTray := .T.

   RETURN Nil

CLASS HMDIChildWindow INHERIT HWindow

   CLASS VAR aMessages INIT { ;
      { WM_ERASEBKGND, WM_COMMAND, WM_MOVE, WM_SIZE, WM_NCACTIVATE, ;
      WM_SYSCOMMAND, WM_CREATE, WM_DESTROY }, ;
      { ;
      {|o,w|onEraseBk( o, w ) },           ;
      {|o,w|onMdiCommand( o, w ) },        ;
      {|o|onMove( o ) },                   ;
      {|o,w,l|hwg_onWndSize( o, w, l ) },  ;
      {|o,w|onMdiNcActivate( o, w ) },     ;
      {|o,w|onSysCommand( o, w ) },        ;
      {|o,w,l|onMdiCreate( o, l ) },       ;
      {|o|hwg_onDestroy( o ) }             ;
      } ;
      }

   METHOD Activate( lShow, lMaximized, lMinimized, bActivate )
   METHOD onEvent( msg, wParam, lParam )

ENDCLASS

METHOD Activate( lShow, lMaximized, lMinimized, bActivate ) CLASS HMDIChildWindow

   hwg_CreateGetList( Self )
   // Hwg_CreateMdiChildWindow( Self )

   ::handle := Hwg_CreateMdiChildWindow( Self )
   ::RedefineScrollbars()

   IF bActivate != NIL
      Eval( bActivate )
   ENDIF

   hwg_InitControls( Self )
   IF ::bInit != Nil
      Eval( ::bInit, Self )
   ENDIF

   RETURN Nil

METHOD onEvent( msg, wParam, lParam )  CLASS HMDIChildWindow

   LOCAL i

   IF ( i := Ascan( ::aMessages[1],msg ) ) != 0
      RETURN Eval( ::aMessages[2,i], Self, wParam, lParam )
   ELSE
      IF msg == WM_HSCROLL .OR. msg == WM_VSCROLL
         IF ::nScrollBars != -1
             hwg_ScrollHV( Self,msg,wParam,lParam )
         ENDIF
         hwg_onTrackScroll( Self, wParam, lParam )
      ENDIF
      Return ::Super:onEvent( msg, wParam, lParam )
   ENDIF

   Return - 1

CLASS HChildWindow INHERIT HWindow

   DATA oNotifyMenu

   METHOD New( oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, oFont, ;
      bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther, ;
      cAppName, oBmp, cHelp, nHelpId, bColor )
   METHOD Activate( lShow )
   METHOD onEvent( msg, wParam, lParam )

ENDCLASS

METHOD New( oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, oFont, ;
      bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther, ;
      cAppName, oBmp, cHelp, nHelpId, bColor ) CLASS HChildWindow

   ::Super:New( oIcon, clr, nStyle, x, y, width, height, cTitle, cMenu, oFont, ;
      bInit, bExit, bSize, bPaint, bGfocus, bLfocus, bOther,  ;
      cAppName, oBmp, cHelp, nHelpId,, bColor )
   ::oParent := HWindow():GetMain()

   IF HB_ISOBJECT( ::oParent )
      ::handle := Hwg_InitChildWindow( Self, ::szAppName, cTitle, cMenu, ;
         Iif( oIcon != Nil, oIcon:handle, Nil ), Iif( oBmp != Nil, - 1, ;
         Iif( ::brush!=Nil, ::brush:handle, clr ) ), nStyle, ::nLeft, ;
         ::nTop, ::nWidth, ::nHeight, ::oParent:handle )
   ELSE
      hwg_Msgstop( "Create Main window first !", "HChildWindow():New()" )
      RETURN Nil
   ENDIF
   IF ::bInit != Nil
      Eval( ::bInit, Self )
   ENDIF

   RETURN Self

METHOD Activate( lShow ) CLASS HChildWindow

   hwg_CreateGetList( Self )
   Hwg_ActivateChildWindow( ( lShow == Nil .OR. lShow ), ::handle )

   RETURN Nil

METHOD onEvent( msg, wParam, lParam )  CLASS HChildWindow

   LOCAL i

   IF msg == WM_DESTROY
      RETURN hwg_onDestroy( Self )
   ELSEIF msg == WM_SIZE
      RETURN hwg_onWndSize( Self, wParam, lParam )
   ELSEIF ( i := Ascan( HMainWindow():aMessages[1],msg ) ) != 0
      RETURN Eval( HMainWindow():aMessages[2,i], Self, wParam, lParam )
   ELSE
      IF msg == WM_HSCROLL .OR. msg == WM_VSCROLL
         hwg_onTrackScroll( Self, wParam, lParam )
      ENDIF
      Return ::Super:onEvent( msg, wParam, lParam )
   ENDIF

   Return - 1

FUNCTION hwg_ReleaseAllWindows( hWnd )

   LOCAL oItem, iCont, nCont

   //  Vamos mandar destruir as filhas
   // Destroi as CHILD's desta MAIN
#ifdef __XHARBOUR__
   FOR EACH oItem IN HWindow():aWindows
      IF oItem:oParent != Nil .AND. oItem:oParent:handle == hWnd
         hwg_Sendmessage( oItem:handle, WM_CLOSE, 0, 0 )
      ENDIF
   NEXT
#else
   nCont := Len( HWindow():aWindows )

   FOR iCont := nCont TO 1 STEP - 1

      IF HWindow():aWindows[iCont]:oParent != Nil .AND. ;
            HWindow():aWindows[iCont]:oParent:handle == hWnd
         hwg_Sendmessage( HWindow():aWindows[iCont]:handle, WM_CLOSE, 0, 0 )
      ENDIF

   NEXT
#endif

   IF HWindow():aWindows[1]:handle == hWnd
      hwg_Postquitmessage( 0 )
   ENDIF

   return - 1

#define  FLAG_CHECK      2

STATIC FUNCTION onCommand( oWnd, wParam, lParam )

   LOCAL iItem, iCont, aMenu, iParHigh, iParLow, nHandle

   wParam := hwg_PtrToUlong( wParam )
   IF wParam == SC_CLOSE
      IF Len( HWindow():aWindows ) > 2 .AND. ( nHandle := hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIGETACTIVE,0,0 ) ) > 0
         hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIDESTROY, nHandle, 0 )
      ENDIF
   ELSEIF wParam == SC_RESTORE
      IF Len( HWindow():aWindows ) > 2 .AND. ( nHandle := hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIGETACTIVE,0,0 ) ) > 0
         hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIRESTORE, nHandle, 0 )
      ENDIF
   ELSEIF wParam == SC_MAXIMIZE
      IF Len( HWindow():aWindows ) > 2 .AND. ( nHandle := hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIGETACTIVE,0,0 ) ) > 0
         hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIMAXIMIZE, nHandle, 0 )
      ENDIF
   ELSEIF wParam >= FIRST_MDICHILD_ID .AND. wparam < FIRST_MDICHILD_ID + MAX_MDICHILD_WINDOWS
      nHandle := HWindow():aWindows[wParam - FIRST_MDICHILD_ID + 3]:handle
      hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIACTIVATE, nHandle, 0 )
   ENDIF
   iParHigh := hwg_Hiword( wParam )
   iParLow := hwg_Loword( wParam )
   IF oWnd:aEvents != Nil .AND. ;
         ( iItem := Ascan( oWnd:aEvents, { |a|a[1] == iParHigh .AND. a[2] == iParLow } ) ) > 0
      Eval( oWnd:aEvents[ iItem,3 ], oWnd, iParLow )
   ELSEIF ValType( oWnd:menu ) == "A" .AND. ;
         ( aMenu := Hwg_FindMenuItem( oWnd:menu,iParLow,@iCont ) ) != Nil
      IF Hwg_BitAnd( aMenu[ 1,iCont,4 ], FLAG_CHECK ) > 0
         hwg_Checkmenuitem( , aMenu[1,iCont,3], !hwg_Ischeckedmenuitem( ,aMenu[1,iCont,3] ) )
      ENDIF
      IF aMenu[ 1,iCont,1 ] != Nil
         Eval( aMenu[ 1,iCont,1 ] )
      ENDIF
   ELSEIF oWnd:oPopup != Nil .AND. ;
         ( aMenu := Hwg_FindMenuItem( oWnd:oPopup:aMenu,wParam,@iCont ) ) != Nil ;
         .AND. aMenu[ 1,iCont,1 ] != Nil
      Eval( aMenu[ 1,iCont,1 ] )
   ELSEIF oWnd:oNotifyMenu != Nil .AND. ;
         ( aMenu := Hwg_FindMenuItem( oWnd:oNotifyMenu:aMenu,wParam,@iCont ) ) != Nil ;
         .AND. aMenu[ 1,iCont,1 ] != Nil
      Eval( aMenu[ 1,iCont,1 ] )
   ENDIF

   RETURN 0

STATIC FUNCTION onMove( oWnd )

   LOCAL aControls := hwg_Getwindowrect( oWnd:handle )

   oWnd:nLeft := aControls[1]
   oWnd:nTop  := aControls[2]

   Return - 1

STATIC FUNCTION onEraseBk( oWnd, hDC )
   LOCAL aCoors

   IF oWnd:oBmp != Nil
      hwg_Spreadbitmap( hDC, oWnd:handle, oWnd:oBmp:handle )
      RETURN 1
   ELSEIF oWnd:brush != Nil .AND. oWnd:type != WND_MAIN
      aCoors := hwg_Getclientrect( oWnd:handle )
      hwg_Fillrect( hDC, aCoors[1], aCoors[2], aCoors[3] + 1, aCoors[4] + 1, oWnd:brush:handle )
      RETURN 1
   ENDIF

   RETURN - 1

STATIC FUNCTION onSysCommand( oWnd, wParam )

   LOCAL i

   wParam := hwg_PtrToUlong( wParam )
   IF wParam == SC_CLOSE
      IF HB_ISBLOCK( oWnd:bDestroy )
         i := Eval( oWnd:bDestroy, oWnd )
         i := Iif( ValType( i ) == "L", i, .T. )
         IF !i
            RETURN 0
         ENDIF
      ENDIF
      IF __ObjHasMsg( oWnd, "ONOTIFYICON" ) .AND. oWnd:oNotifyIcon != Nil
         hwg_Shellnotifyicon( .F. , oWnd:handle, oWnd:oNotifyIcon:handle )
      ENDIF
      IF __ObjHasMsg( oWnd, "HACCEL" ) .AND. oWnd:hAccel != Nil
         hwg_Destroyacceleratortable( oWnd:hAccel )
      ENDIF
   ELSEIF wParam == SC_MINIMIZE
      IF __ObjHasMsg( oWnd, "LTRAY" ) .AND. oWnd:lTray
         oWnd:Hide()
         RETURN 0
      ENDIF
   ENDIF

   Return - 1

STATIC FUNCTION onEndSession( oWnd )

   LOCAL i

   IF HB_ISBLOCK( oWnd:bDestroy )
      i := Eval( oWnd:bDestroy, oWnd )
      i := Iif( ValType( i ) == "L", i, .T. )
      IF !i
         RETURN 0
      ENDIF
   ENDIF

   Return - 1

STATIC FUNCTION onNotifyIcon( oWnd, wParam, lParam )

   LOCAL ar

   wParam := hwg_PtrToUlong( wParam )
   lParam := hwg_PtrToUlong( lParam )
   IF wParam == ID_NOTIFYICON
      IF lParam == WM_LBUTTONDOWN
         IF HB_ISBLOCK( oWnd:bNotify )
            Eval( oWnd:bNotify )
         ENDIF
      ELSEIF lParam == WM_RBUTTONDOWN
         IF oWnd:oNotifyMenu != Nil
            ar := hwg_GetCursorPos()
            oWnd:oNotifyMenu:Show( oWnd, ar[1], ar[2] )
         ENDIF
      ENDIF
   ENDIF

   Return - 1

STATIC FUNCTION onMdiCreate( oWnd, lParam )

   hwg_InitControls( oWnd )
   IF oWnd:bInit != Nil
      Eval( oWnd:bInit, oWnd )
   ENDIF

   Return - 1

STATIC FUNCTION onMdiCommand( oWnd, wParam )

   LOCAL iParHigh, iParLow, iItem

   wParam := hwg_PtrToUlong( wParam )
   IF wParam == SC_CLOSE
      hwg_Sendmessage( HWindow():aWindows[2]:handle, WM_MDIDESTROY, oWnd:handle, 0 )
   ENDIF
   iParHigh := hwg_Hiword( wParam )
   iParLow := hwg_Loword( wParam )
   IF oWnd:aEvents != Nil .AND. ;
         ( iItem := Ascan( oWnd:aEvents, { |a|a[1] == iParHigh .AND. a[2] == iParLow } ) ) > 0
      Eval( oWnd:aEvents[ iItem,3 ], oWnd, iParLow )
   ENDIF

   RETURN 0

STATIC FUNCTION onMdiNcActivate( oWnd, wParam )

   wParam := hwg_PtrToUlong( wParam )
   IF wParam == 1 .AND. oWnd:bGetFocus != Nil
      Eval( oWnd:bGetFocus, oWnd )
   ELSEIF wParam == 0 .AND. oWnd:bLostFocus != Nil
      Eval( oWnd:bLostFocus, oWnd )
   ENDIF

   Return - 1

   //add by sauli

STATIC FUNCTION onCloseQuery( o )

   IF ValType( o:bCloseQuery ) = 'B'
      IF Eval( o:bCloseQuery )
         hwg_ReleaseAllWindows( o:handle )
      end
   ELSE
      hwg_ReleaseAllWindows( o:handle )
   end

   return - 1

   // end sauli
