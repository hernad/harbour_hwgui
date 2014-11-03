/*
 * $Id: hownbtn.prg 2086 2013-06-23 12:57:56Z alkresin $
 *
 * HWGUI - Harbour Win32 GUI library source code:
 * HOwnButton class, which implements owner drawn buttons
 *
 * Copyright 2002 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "windows.ch"
#include "inkey.ch"
#include "hbclass.ch"
#include "guilib.ch"
#include "common.ch"

CLASS HOwnButton INHERIT HControl

CLASS VAR cPath SHARED
   DATA winclass   INIT "OWNBTN"
   DATA lFlat
   DATA state
   DATA bClick
   DATA lPress  INIT .F.
   DATA lCheck  INIT .f.
   DATA xt, yt, widtht, heightt
   DATA oBitmap, xb, yb, widthb, heightb, lTransp, trColor
   DATA lEnabled INIT .T.
   DATA nOrder

   METHOD New( oWndParent, nId, nStyle, nLeft, nTop, nWidth, nHeight, ;
               bInit, bSize, bPaint, bClick, lflat,              ;
               cText, color, font, xt, yt, widtht, heightt,        ;
               bmp, lResour, xb, yb, widthb, heightb, lTr, trColor, ;
               cTooltip, lEnabled, lCheck )

   METHOD Activate()
   METHOD onEvent( msg, wParam, lParam )
   METHOD Init()
   METHOD Redefine( oWndParent, nId, bInit, bSize, bPaint, bClick, lflat, ;
                    cText, color, font, xt, yt, widtht, heightt,     ;
                    bmp, lResour, xb, yb, widthb, heightb, lTr,      ;
                    cTooltip, lEnabled, lCheck, bColor,bGfocus, bLfocus )
   METHOD Paint()
   METHOD DrawItems( hDC )
   METHOD MouseMove( wParam, lParam )
   METHOD MDown()
   METHOD MUp()
   METHOD Press()   INLINE ( ::lPress := .T., ::MDown() )
   METHOD Release()
   METHOD END()
   METHOD Enable()
   METHOD Disable()

ENDCLASS

METHOD New( oWndParent, nId, nStyle, nLeft, nTop, nWidth, nHeight,   ;
            bInit, bSize, bPaint, bClick, lflat,             ;
            cText, color, oFont, xt, yt, widtht, heightt,       ;
            bmp, lResour, xb, yb, widthb, heightb, lTr, trColor, ;
            cTooltip, lEnabled, lCheck, bColor,bGfocus, bLfocus ) CLASS HOwnButton

   ::Super:New( oWndParent, nId, nStyle, nLeft, nTop, nWidth, nHeight, oFont, bInit, ;
              bSize, bPaint, cTooltip )

   IF oFont == Nil
      ::oFont := ::oParent:oFont
   ENDIF
   ::lflat   := IIf( lflat == Nil, .F., lflat )
   ::bClick  := bClick
   ::state   := OBTN_INIT
   ::nOrder  := IIf( oWndParent == nil, 0, Len( oWndParent:aControls ) )

   ::title   := cText
   ::tcolor  := IIf( color == Nil, hwg_Getsyscolor( COLOR_BTNTEXT ), color )
   ::bcolor  := bcolor
   IF bColor != Nil
      ::brush := HBrush():Add( bcolor )
   ENDIF
   ::xt      := IIf( xt == Nil, 0, xt )
   ::yt      := IIf( yt == Nil, 0, yt )
   ::widtht  := IIf( widtht == Nil, 0, widtht )
   ::heightt := IIf( heightt == Nil, 0, heightt )

   IF lEnabled != Nil
      ::lEnabled := lEnabled
   ENDIF
   IF lCheck != Nil
      ::lCheck := lCheck
   ENDIF
   IF bmp != Nil
      IF ValType( bmp ) == "O"
         ::oBitmap := bmp
      ELSE
         ::oBitmap := IIf( ( lResour != Nil.AND.lResour ) .OR.Valtype( bmp ) == "N", ;
                           HBitmap():AddResource( bmp ), ;
                           HBitmap():AddFile( IIf( ::cPath != Nil, ::cPath + bmp, bmp ) ) )
      ENDIF
   ENDIF
   ::xb      := xb
   ::yb      := yb
   ::widthb  := IIf( widthb == Nil, 0, widthb )
   ::heightb := IIf( heightb == Nil, 0, heightb )
   ::lTransp := IIf( lTr != Nil, lTr, .F. )
   ::trColor := trColor

   hwg_RegOwnBtn()
   ::Activate()

   RETURN Self

METHOD Activate CLASS HOwnButton
   IF ! Empty( ::oParent:handle )
      ::handle := hwg_Createownbtn( ::oParent:handle, ::id, ;
                                ::nLeft, ::nTop, ::nWidth, ::nHeight )
      ::Init()
      IF ! ::lEnabled
         hwg_Enablewindow( ::handle, .f. )
         ::Disable()
      ENDIF
   ENDIF
   RETURN Nil

METHOD onEvent( msg, wParam, lParam )  CLASS HOwnButton

   IF msg == WM_PAINT
      IF ::bPaint != Nil
         Eval( ::bPaint, Self )
      ELSE
         ::Paint()
      ENDIF
   ELSEIF msg == WM_ERASEBKGND
      RETURN 1
   ELSEIF msg == WM_MOUSEMOVE
      ::MouseMove( wParam, lParam )
   ELSEIF msg == WM_LBUTTONDOWN
      ::MDown()
   ELSEIF msg == WM_LBUTTONUP
      ::MUp()
   ELSEIF msg == WM_DESTROY
      ::END()
   ELSEIF msg == WM_SETFOCUS
      IF ! Empty( ::bGetfocus )
         Eval( ::bGetfocus, Self, msg, wParam, lParam )
      ENDIF
   ELSEIF msg == WM_KILLFOCUS
      ::release()
      IF ! Empty( ::bLostfocus )
         Eval( ::bLostfocus, Self, msg, wParam, lParam )
      ENDIF
   ELSE
      IF ! Empty( ::bOther )
         Eval( ::bOther, Self, msg, wParam, lParam )
      ENDIF
   ENDIF

   RETURN - 1

METHOD Init CLASS HOwnButton

   IF ! ::lInit
      ::nHolder := 1
      hwg_Setwindowobject( ::handle, Self )
      ::Super:Init()
   ENDIF

   RETURN Nil

METHOD Redefine( oWndParent, nId, bInit, bSize, bPaint, bClick, lflat, ;
                 cText, color, font, xt, yt, widtht, heightt,     ;
                 bmp, lResour, xb, yb, widthb, heightb, lTr,      ;
                 cTooltip, lEnabled, lCheck ) CLASS HOwnButton

   ::Super:New( oWndParent, nId, 0, 0, 0, 0, 0,, bInit, bSize, bPaint, cTooltip )

   ::lflat   := IIf( lflat == Nil, .F., lflat )
   ::bClick  := bClick
   ::state   := OBTN_INIT

   ::title   := cText
   ::tcolor  := IIf( color == Nil, hwg_Getsyscolor( COLOR_BTNTEXT ), color )
   ::ofont   := font
   ::xt      := IIf( xt == Nil, 0, xt )
   ::yt      := IIf( yt == Nil, 0, yt )
   ::widtht  := IIf( widtht == Nil, 0, widtht )
   ::heightt := IIf( heightt == Nil, 0, heightt )

   IF lEnabled != Nil
      ::lEnabled := lEnabled
   ENDIF
   IF lEnabled != Nil
      ::lEnabled := lEnabled
   ENDIF
   IF lCheck != Nil
      ::lCheck := lCheck
   ENDIF

   IF bmp != Nil
      IF ValType( bmp ) == "O"
         ::oBitmap := bmp
      ELSE
         ::oBitmap := IIf( lResour, HBitmap():AddResource( bmp ), ;
                           HBitmap():AddFile( bmp ) )
      ENDIF
   ENDIF
   ::xb      := xb
   ::yb      := yb
   ::widthb  := IIf( widthb == Nil, 0, widthb )
   ::heightb := IIf( heightb == Nil, 0, heightb )
   ::lTransp := IIf( lTr != Nil, lTr, .F. )
   hwg_RegOwnBtn()

   RETURN Self

METHOD Paint() CLASS HOwnButton
   LOCAL pps, hDC
   LOCAL aCoors

   pps := hwg_Definepaintstru()

   hDC := hwg_Beginpaint( ::handle, pps )

   aCoors := hwg_Getclientrect( ::handle )

   IF ::state == OBTN_INIT
      ::state := OBTN_NORMAL
   ENDIF
   IF ::nWidth != aCoors[ 3 ] .OR. ::nHeight != aCoors[ 4 ]
      ::nWidth  := aCoors[ 3 ]
      ::nHeight := aCoors[ 4 ]
   ENDIF

   IF ::lFlat
      IF ::state == OBTN_NORMAL
         IF ::handle != hwg_Getfocus()
            // NORM
            hwg_Drawbutton( hDC, 0, 0, aCoors[ 3 ], aCoors[ 4 ], 0 )
         ELSE
            hwg_Drawbutton( hDC, 0, 0, aCoors[ 3 ], aCoors[ 4 ], 1 )
         ENDIF  
      ELSEIF ::state == OBTN_MOUSOVER
        hwg_Drawbutton( hDC, 0, 0, aCoors[ 3 ], aCoors[ 4 ], 1 )
      ELSEIF ::state == OBTN_PRESSED
         hwg_Drawbutton( hDC, 0, 0, aCoors[ 3 ], aCoors[ 4 ], 2 )
      ENDIF
   ELSE
      IF ::state == OBTN_NORMAL
         hwg_Drawbutton( hDC, 0, 0, aCoors[ 3 ], aCoors[ 4 ], 5 )
      ELSEIF ::state == OBTN_PRESSED
         hwg_Drawbutton( hDC, 0, 0, aCoors[ 3 ], aCoors[ 4 ], 6 )
      ENDIF
   ENDIF

   ::DrawItems( hDC )

   hwg_Endpaint( ::handle, pps )
   RETURN Nil

METHOD DrawItems( hDC ) CLASS HOwnButton
   LOCAL x1, y1, x2, y2,  aCoors

   aCoors := hwg_Getclientrect( ::handle )
   IF ! EMPTY( ::brush )
      hwg_Fillrect( hDC, aCoors[ 1 ] + 2, aCoors[ 2 ] + 2, aCoors[ 3 ] - 2, aCoors[ 4 ] - 2, ::Brush:handle )
   ENDIF   

   IF ::oBitmap != Nil
      IF ::widthb == 0
         ::widthb := ::oBitmap:nWidth
         ::heightb := ::oBitmap:nHeight
      ENDIF
      x1 := IIf( ::xb != Nil .AND. ::xb != 0, ::xb, ;
                 Round( ( ::nWidth - ::widthb ) / 2, 0 ) )
      y1 := IIf( ::yb != Nil .AND. ::yb != 0, ::yb, ;
                 Round( ( ::nHeight - ::heightb ) / 2, 0 ) )
      IF ::lEnabled
         IF ::oBitmap:ClassName() == "HICON"
            hwg_Drawicon( hDC, ::oBitmap:handle, x1, y1 )
         ELSE
            IF ::lTransp
               hwg_Drawtransparentbitmap( hDC, ::oBitmap:handle, x1, y1, ::trColor )
            ELSE
               hwg_Drawbitmap( hDC, ::oBitmap:handle,, x1, y1, ::widthb, ::heightb )
            ENDIF
         ENDIF
      ELSE
         hwg_Drawgraybitmap( hDC, ::oBitmap:handle, x1, y1 )
      ENDIF
   ENDIF

   IF ::title != Nil
      IF ::oFont != Nil
         hwg_Selectobject( hDC, ::oFont:handle )
      ENDIF
      IF ::lEnabled
         hwg_Settextcolor( hDC, ::tcolor )
      ELSE
         hwg_Settextcolor( hDC, hwg_Rgb( 255, 255, 255 ) )
      ENDIF
      x1 := IIf( ::xt != 0, ::xt, 4 )
      y1 := IIf( ::yt != 0, ::yt, 4 )
      x2 := ::nWidth - 4
      y2 := ::nHeight - 4
      hwg_Settransparentmode( hDC, .T. )
      hwg_Drawtext( hDC, ::title, x1, y1, x2, y2, ;
                IIf( ::xt != 0, DT_LEFT, DT_CENTER ) + IIf( ::yt != 0, DT_TOP, DT_VCENTER + DT_SINGLELINE ) )
      hwg_Settransparentmode( hDC, .F. )
   ENDIF

   RETURN Nil

METHOD MouseMove( wParam, lParam )  CLASS HOwnButton
   LOCAL xPos, yPos
   LOCAL res := .F.

   HB_SYMBOL_UNUSED( wParam )

   IF ::state != OBTN_INIT
      xPos := hwg_Loword( lParam )
      yPos := hwg_Hiword( lParam )
      IF xPos > ::nWidth .OR. yPos > ::nHeight
         hwg_Releasecapture()
         res := .T.
      ENDIF

      IF res .AND. ! ::lPress
         ::state := OBTN_NORMAL
         hwg_Invalidaterect( ::handle, 0 )
         // hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
      ENDIF
      IF ::state == OBTN_NORMAL .AND. ! res
         ::state := OBTN_MOUSOVER
         hwg_Invalidaterect( ::handle, 0 )
         // hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
         hwg_Setcapture( ::handle )
      ENDIF
   ENDIF
   RETURN Nil

METHOD MDown()  CLASS HOwnButton
   IF ::state != OBTN_PRESSED
      ::state := OBTN_PRESSED
      hwg_Invalidaterect( ::handle, 0 )
      hwg_Setfocus( ::handle )
      // hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
   ENDIF
   RETURN Nil

METHOD MUp() CLASS HOwnButton
   IF ::state == OBTN_PRESSED
      IF ! ::lPress
         //::state := OBTN_NORMAL  // IIF( ::lFlat,OBTN_MOUSOVER,OBTN_NORMAL )
         ::state := IIF( ::lFlat, OBTN_MOUSOVER, OBTN_NORMAL )
      ENDIF
      IF ::lCheck
         IF ::lPress
            ::Release()
         ELSE
            ::Press()
         ENDIF
      ENDIF
      IF ::bClick != Nil
         hwg_Releasecapture()
         Eval( ::bClick, ::oParent, ::id )
      ENDIF
      hwg_Invalidaterect( ::handle, 0 )
//    hwg_Sendmessage( ::handle, WM_PAINT, 0, 0 )
   ENDIF

   RETURN Nil

METHOD Release()  CLASS HOwnButton
   ::lPress := .F.
   ::state := OBTN_NORMAL
   hwg_Invalidaterect( ::handle, 0 )
   // hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
   RETURN Nil

METHOD END()  CLASS HOwnButton

   ::Super:END()
   ::oFont := Nil
   IF ::oBitmap != Nil
      ::oBitmap:Release()
      ::oBitmap := Nil
   ENDIF
   hwg_Postmessage( ::handle, WM_CLOSE, 0, 0 )
   RETURN Nil

METHOD Enable() CLASS HOwnButton

   hwg_Enablewindow( ::handle, .T. )
   ::lEnabled := .T.
   hwg_Invalidaterect( ::handle, 0 )
   // hwg_Sendmessage( ::handle, WM_PAINT, 0, 0 )
   //::Init() BECAUSE ERROR GPF

   RETURN Nil

METHOD Disable() CLASS HOwnButton

   ::state   := OBTN_INIT
   ::lEnabled := .F.
   hwg_Invalidaterect( ::handle, 0 )
   // hwg_Sendmessage( ::handle, WM_PAINT, 0, 0 )
   hwg_Enablewindow( ::handle, .F. )

   RETURN Nil
