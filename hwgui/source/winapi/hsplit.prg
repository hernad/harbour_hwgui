/*
 * $Id: hsplit.prg 2086 2013-06-23 12:57:56Z alkresin $
 *
 * HWGUI - Harbour Win32 GUI library source code:
 * HSplitter class
 *
 * Copyright 2003 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

#include "windows.ch"
#include "hbclass.ch"
#include "guilib.ch"
#include "common.ch"

CLASS HSplitter INHERIT HControl

CLASS VAR winclass INIT "STATIC"

   DATA aLeft
   DATA aRight
   DATA lVertical
   DATA hCursor
   DATA lCaptured INIT .F.
   DATA lMoved INIT .F.
   DATA bEndDrag

   METHOD New( oWndParent, nId, nLeft, nTop, nWidth, nHeight, ;
               bSize, bPaint, color, bcolor, aLeft, aRight )
   METHOD Activate()
   METHOD onEvent( msg, wParam, lParam )
   METHOD Init()
   METHOD Paint()
   METHOD Drag( lParam )
   METHOD DragAll()

ENDCLASS

METHOD New( oWndParent, nId, nLeft, nTop, nWidth, nHeight, ;
            bSize, bDraw, color, bcolor, aLeft, aRight ) CLASS HSplitter

   ::Super:New( oWndParent, nId, WS_CHILD + WS_VISIBLE + SS_OWNERDRAW, nLeft, nTop, nWidth, nHeight,,, ;
              bSize, bDraw,, Iif(color==Nil,0,color), bcolor )

   ::title   := ""
   ::aLeft   := IIf( aLeft == Nil, { }, aLeft )
   ::aRight  := IIf( aRight == Nil, { }, aRight )
   ::lVertical := ( ::nHeight > ::nWidth )

   ::Activate()

   RETURN Self

METHOD Activate() CLASS HSplitter
   IF ! Empty( ::oParent:handle )
      ::handle := hwg_Createstatic( ::oParent:handle, ::id, ;
                                ::style, ::nLeft, ::nTop, ::nWidth, ::nHeight )
      ::Init()
   ENDIF
   RETURN Nil

METHOD onEvent( msg, wParam, lParam ) CLASS HSplitter

   HB_SYMBOL_UNUSED( wParam )

   IF msg == WM_MOUSEMOVE
      IF ::hCursor == Nil
         ::hCursor := hwg_Loadcursor( IIf( ::lVertical, IDC_SIZEWE, IDC_SIZENS ) )
      ENDIF
      Hwg_SetCursor( ::hCursor )
      IF ::lCaptured
         ::Drag( lParam )
      ENDIF
   ELSEIF msg == WM_PAINT
      ::Paint()
   ELSEIF msg == WM_ERASEBKGND
      IF ::brush != Nil
         hwg_Fillrect( wParam, 0, 0, ::nWidth, ::nHeight, ::brush:handle )
         RETURN 1
      ENDIF
   ELSEIF msg == WM_LBUTTONDOWN
      Hwg_SetCursor( ::hCursor )
      hwg_Setcapture( ::handle )
      ::lCaptured := .T.
   ELSEIF msg == WM_LBUTTONUP
      hwg_Releasecapture()
      ::DragAll()
      ::lCaptured := .F.
      IF ::bEndDrag != Nil
         Eval( ::bEndDrag, Self )
      ENDIF
   ELSEIF msg == WM_DESTROY
      ::END()
   ENDIF

   RETURN - 1

METHOD Init CLASS HSplitter

   IF ! ::lInit
      ::Super:Init()
      ::nHolder := 1
      hwg_Setwindowobject( ::handle, Self )
      Hwg_InitWinCtrl( ::handle )
   ENDIF

   RETURN Nil

METHOD Paint() CLASS HSplitter
   LOCAL pps, hDC, aCoors, x1, y1, x2, y2


   pps := hwg_Definepaintstru()
   hDC := hwg_Beginpaint( ::handle, pps )
   aCoors := hwg_Getclientrect( ::handle )
   x1 := aCoors[ 1 ] + IIf( ::lVertical, 1, 5 )
   y1 := aCoors[ 2 ] + IIf( ::lVertical, 5, 1 )
   x2 := aCoors[ 3 ] - IIf( ::lVertical, 0, 5 )
   y2 := aCoors[ 4 ] - IIf( ::lVertical, 5, 0 )

   IF ::bPaint != Nil
      Eval( ::bPaint, Self )
   ELSE
      hwg_Drawedge( hDC, x1, y1, x2, y2, EDGE_ETCHED, IIf( ::lVertical, BF_LEFT, BF_TOP ) )
   ENDIF
   hwg_Endpaint( ::handle, pps )

   RETURN Nil

METHOD Drag( lParam ) CLASS HSplitter
   LOCAL xPos := hwg_Loword( lParam ), yPos := hwg_Hiword( lParam )

   IF ::lVertical
      IF xPos > 32000
         xPos -= 65535
      ENDIF
      ::nLeft += xPos
   ELSE
      IF yPos > 32000
         yPos -= 65535
      ENDIF
      ::nTop += yPos
   ENDIF
   hwg_Movewindow( ::handle, ::nLeft, ::nTop, ::nWidth, ::nHeight )
   ::lMoved := .T.

   RETURN Nil

METHOD DragAll() CLASS HSplitter
   LOCAL i, oCtrl, nDiff

   FOR i := 1 TO Len( ::aRight )
      oCtrl := ::aRight[ i ]
      IF ::lVertical
         nDiff := ::nLeft + ::nWidth - oCtrl:nLeft
         oCtrl:nLeft += nDiff
         oCtrl:nWidth -= nDiff
      ELSE
         nDiff := ::nTop + ::nHeight - oCtrl:nTop
         oCtrl:nTop += nDiff
         oCtrl:nHeight -= nDiff
      ENDIF
      oCtrl:Move( oCtrl:nLeft, oCtrl:nTop, oCtrl:nWidth, oCtrl:nHeight )
   NEXT
   FOR i := 1 TO Len( ::aLeft )
      oCtrl := ::aLeft[ i ]
      IF ::lVertical
         nDiff := ::nLeft - ( oCtrl:nLeft + oCtrl:nWidth )
         oCtrl:nWidth += nDiff
      ELSE
         nDiff := ::nTop - ( oCtrl:nTop + oCtrl:nHeight )
         oCtrl:nHeight += nDiff
      ENDIF
      oCtrl:Move( oCtrl:nLeft, oCtrl:nTop, oCtrl:nWidth, oCtrl:nHeight )
   NEXT
   ::lMoved := .F.

   RETURN Nil

