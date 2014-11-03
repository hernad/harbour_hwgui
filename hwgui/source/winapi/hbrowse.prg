/*
 * $Id: hbrowse.prg 2275 2014-07-03 09:35:02Z alkresin $
 *
 * HWGUI - Harbour Win32 GUI library source code:
 * HBrowse class - browse databases and arrays
 *
 * Copyright 2002 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
*/

   // Modificaciones y Agregados. 27.07.2002, WHT.de la Argentina ///////////////
   // 1) En el metodo HColumn se agregaron las DATA: "nJusHead" y "nJustLin",  //
   //    para poder justificar los encabezados de columnas y tambien las       //
   //    lineas. Por default es DT_LEFT                                        //
   //    0-DT_LEFT, 1-DT_RIGHT y 2-DT_CENTER. 27.07.2002. WHT.                 //
   // 2) Ahora la variable "cargo" del metodo Hbrowse si es codeblock          //
   //    ejectuta el CB. 27.07.2002. WHT                                       //
   // 3) Se agreg� el Metodo "ShowSizes". Para poder ver la "width" de cada    //
   //    columna. 27.07.2002. WHT.                                             //
   //////////////////////////////////////////////////////////////////////////////

#include "windows.ch"
#include "inkey.ch"
#include "dbstruct.ch"
#include "hbclass.ch"
#include "guilib.ch"

#ifdef __XHARBOUR__
#xtranslate hb_tokenGet([<x>,<n>,<c>] ) =>  __StrToken(<x>,<n>,<c>)
#xtranslate hb_tokenPtr([<x>,<n>,<c>] ) =>  __StrTkPtr(<x>,<n>,<c>)
#endif

   REQUEST DBGOTOP
   REQUEST DBGOTO
   REQUEST DBGOBOTTOM
   REQUEST DBSKIP
   REQUEST RECCOUNT
   REQUEST RECNO
   REQUEST EOF
   REQUEST BOF

/*
 * Scroll Bar Constants
 */
#ifndef SB_HORZ
#define SB_HORZ             0
#define SB_VERT             1
#define SB_CTL              2
#define SB_BOTH             3
#endif

#define HDM_GETITEMCOUNT    4608

   // #define DLGC_WANTALLKEYS    0x0004      /* Control wants all keys */

   STATIC ColSizeCursor := 0
   STATIC arrowCursor := 0
   STATIC oCursor     := 0
   STATIC xDrag

   //----------------------------------------------------//

CLASS HColumn INHERIT HObject

   DATA block, heading, footing, width, type
   DATA length INIT 0
   DATA dec, cargo
   DATA nJusHead, nJusLin        // Para poder Justificar los Encabezados
   // de las columnas y lineas.
   // WHT. 27.07.2002
   DATA tcolor, bcolor, brush
   DATA oFont
   DATA lEditable INIT .F.       // Is the column editable
   DATA aList                    // Array of possible values for a column -
   // combobox will be used while editing the cell
   DATA aBitmaps
   DATA bValid, bWhen             // When and Valid codeblocks for cell editing
   DATA bEdit                    // Codeblock, which performs cell editing, if defined
   DATA cGrid
   DATA lSpandHead INIT .F.
   DATA lSpandFoot INIT .F.
   DATA PICTURE
   DATA bHeadClick
   DATA bColorBlock              //   bColorBlock must return an array containing four colors values
   //   oBrowse:aColumns[1]:bColorBlock := {|| IF (nNumber < 0, ;
   //      {textColor, backColor, textColorSel, backColorSel} , ;
   //      {textColor, backColor, textColorSel, backColorSel} ) }
   METHOD New( cHeading, block, type, length, dec, lEditable, nJusHead, nJusLin, cPict, bValid, bWhen, aItem, bColorBlock, bHeadClick )

ENDCLASS

   //----------------------------------------------------//

METHOD New( cHeading, block, type, length, dec, lEditable, nJusHead, nJusLin, cPict, bValid, bWhen, aItem, bColorBlock, bHeadClick ) CLASS HColumn

   ::heading   := iif( cHeading == nil, "", cHeading )
   ::block     := block
   ::type      := type
   ::length    := length
   ::dec       := dec
   ::lEditable := iif( lEditable != Nil, lEditable, .F. )
   ::nJusHead  := iif( nJusHead == nil,  DT_LEFT , nJusHead )  // Por default
   ::nJusLin   := iif( nJusLin  == nil,  DT_LEFT , nJusLin  )  // Justif.Izquierda
   ::picture   := cPict
   ::bValid    := bValid
   ::bWhen     := bWhen
   ::aList     := aItem
   ::bColorBlock := bColorBlock
   ::bHeadClick  := bHeadClick

   RETURN Self

   //----------------------------------------------------//

CLASS HBrowse INHERIT HControl

   DATA winclass   INIT "BROWSE"
   DATA active     INIT .T.
   DATA lChanged   INIT .F.
   DATA lDispHead  INIT .T.                    // Should I display headers ?
   DATA lDispSep   INIT .T.                    // Should I display separators ?
   DATA aColumns                               // HColumn's array
   DATA aColAlias  INIT {}
   DATA aRelation  INIT .F.
   DATA rowCount                               // Number of visible data rows
   DATA rowPos     INIT 1                      // Current row position
   DATA rowCurrCount INIT 0                    // Current number of rows
   DATA colPos     INIT 1                      // Current column position
   DATA nColumns                               // Number of visible data columns
   DATA nLeftCol                               // Leftmost column
   DATA xpos
   DATA freeze                                 // Number of columns to freeze
   DATA nRecords                               // Number of records in browse
   DATA nCurrent   INIT 1                     // Current record
   DATA aArray                                 // An array browsed if this is BROWSE ARRAY
   DATA recCurr    INIT 0
   DATA headColor                              // Header text color
   DATA sepColor   INIT 12632256               // Separators color
   DATA lSep3d     INIT .F.
   DATA lInFocus   INIT .F.                    // Set focus in :Paint()
   DATA varbuf                                 // Used on Edit()
   DATA tcolorSel, bcolorSel, brushSel, htbColor, httColor // Hilite Text Back Color
   DATA bSkip, bGoTo, bGoTop, bGoBot, bEof, bBof
   DATA bRcou, bRecno, bRecnoLog
   DATA bPosChanged, bLineOut
   DATA bScrollPos                             // Called when user move browse through vertical scroll bar
   DATA bHScrollPos                            // Called when user move browse through horizontal scroll bar
   DATA bEnter, bKeyDown, bUpdate, bRClick
   DATA internal
   DATA ALIAS                                  // Alias name of browsed database
   DATA x1, y1, x2, y2, width, height
   DATA minHeight INIT 0
   DATA lEditable INIT .T.
   DATA lAppable  INIT .F.
   DATA lAppMode  INIT .F.
   DATA lAutoEdit INIT .F.
   DATA lUpdated  INIT .F.
   DATA lAppended INIT .F.
   DATA lAdjRight INIT .T.                     // Adjust last column to right
   DATA nHeadRows INIT 1                       // Rows in header
   DATA nFootRows INIT 0                       // Rows in footer
   DATA lResizing INIT .F.                     // .T. while a column resizing is undergoing
   DATA lCtrlPress INIT .F.                    // .T. while Ctrl key is pressed
   DATA aSelected                              // An array of selected records numbers
   // By Luiz Henrique dos Santos (luizhsantos@gmail.com)
   DATA lDescend INIT .F.              // Descend Order?
   DATA lFilter INIT .F.               // Filtered? (atribuition is automatic in method "New()").
   DATA bFirst INIT { || DBGOTOP() }     // Block to place pointer in first record of condition filter. (Ex.: DbGoTop(), DbSeek(), etc.).
   DATA bLast  INIT { || dbGoBottom() }  // Block to place pointer in last record of condition filter. (Ex.: DbGoBottom(), DbSeek(), etc.).
   DATA bWhile INIT { || .T. }           // Clausule "while". Return logical.
   DATA bFor INIT { || .T. }             // Clausule "for". Return logical.
   DATA nLastRecordFilter INIT 0       // Save the last record of filter.
   DATA nFirstRecordFilter INIT 0      // Save the first record of filter.
   DATA nPaintRow, nPaintCol                   // Row/Col being painted

   METHOD New( lType, oWndParent, nId, nStyle, nLeft, nTop, nWidth, nHeight, oFont, ;
      bInit, bSize, bPaint, bEnter, bGfocus, bLfocus, lNoVScroll, lNoBorder, ;
      lAppend, lAutoedit, bUpdate, bKeyDown, bPosChg, lMultiSelect, bFirst, bWhile, bFor, bRClick )
   METHOD InitBrw( nType )
   METHOD Rebuild()
   METHOD Activate()
   METHOD Init()
   METHOD onEvent( msg, wParam, lParam )
   METHOD Redefine( lType, oWnd, nId, oFont, bInit, bSize, bPaint, bEnter, bGfocus, bLfocus )
   METHOD FindBrowse( nId )
   METHOD AddColumn( oColumn )
   METHOD InsColumn( oColumn, nPos )
   METHOD DelColumn( nPos )
   METHOD Paint( lLostFocus )
   METHOD LineOut()
   METHOD HeaderOut( hDC )
   METHOD FooterOut( hDC )
   METHOD SetColumn( nCol )
   METHOD DoHScroll( wParam )
   METHOD DoVScroll( wParam )
   METHOD LineDown( lMouse )
   METHOD LineUp()
   METHOD PageUp()
   METHOD PageDown()
   METHOD Bottom( lPaint )
   METHOD Top()
   METHOD Home()  INLINE ::DoHScroll( SB_LEFT )
   METHOD ButtonDown( lParam )
   METHOD ButtonRDown( lParam )
   METHOD ButtonUp( lParam )
   METHOD ButtonDbl( lParam )
   METHOD MouseMove( wParam, lParam )
   METHOD MouseWheel( nKeys, nDelta, nXPos, nYPos )
   METHOD Edit( wParam, lParam )
   METHOD APPEND() INLINE ( ::Bottom( .F. ), ::LineDown() )
   METHOD RefreshLine()
   METHOD Refresh( lFull )
   METHOD ShowSizes()
   METHOD End()

ENDCLASS

   //----------------------------------------------------//

METHOD New( lType, oWndParent, nId, nStyle, nLeft, nTop, nWidth, nHeight, oFont, ;
      bInit, bSize, bPaint, bEnter, bGfocus, bLfocus, lNoVScroll, ;
      lNoBorder, lAppend, lAutoedit, bUpdate, bKeyDown, bPosChg, lMultiSelect, ;
      lDescend, bWhile, bFirst, bLast, bFor, bRClick ) CLASS HBrowse

   nStyle   := Hwg_BitOr( iif( nStyle == Nil,0,nStyle ), WS_CHILD + WS_VISIBLE +  ;
      iif( lNoBorder = Nil .OR. !lNoBorder, WS_BORDER, 0 ) +            ;
      iif( lNoVScroll = Nil .OR. !lNoVScroll, WS_VSCROLL, 0 ) )

   ::Super:New( oWndParent, nId, nStyle, nLeft, nTop, iif( nWidth == Nil,0,nWidth ), ;
      iif( nHeight == Nil, 0, nHeight ), oFont, bInit, bSize, bPaint )

   ::type    := lType
   IF oFont == Nil
      ::oFont := ::oParent:oFont
   ENDIF
   ::bEnter  := bEnter
   ::bRClick := bRClick
   ::bGetFocus   := bGFocus
   ::bLostFocus  := bLFocus

   ::lAppable    := iif( lAppend == Nil, .F. , lAppend )
   ::lAutoEdit   := iif( lAutoedit == Nil, .F. , lAutoedit )
   ::bUpdate     := bUpdate
   ::bKeyDown    := bKeyDown
   ::bPosChanged := bPosChg
   IF lMultiSelect != Nil .AND. lMultiSelect
      ::aSelected := {}
   ENDIF
   ::lDescend    := iif( lDescend == Nil, .F. , lDescend )

   // By Luiz Henrique dos Santos (luizhsantos@gmail.com)
   IF HB_ISBLOCK( bFirst ) .OR. HB_ISBLOCK( bFor ) .OR. HB_ISBLOCK( bWhile )
      ::lFilter := .T.
      IF HB_ISBLOCK( bFirst )
         ::bFirst  := bFirst
      ENDIF
      IF HB_ISBLOCK( bLast )
         ::bLast   := bLast
      ENDIF
      IF HB_ISBLOCK( bWhile )
         ::bWhile  := bWhile
      ENDIF
      IF HB_ISBLOCK( bFor )
         ::bFor    := bFor
      ENDIF
   ELSE
      ::lFilter := .F.
   ENDIF

   hwg_RegBrowse()
   ::InitBrw()
   ::Activate()

   RETURN Self

   //----------------------------------------------------//

METHOD Activate CLASS HBrowse

   IF !Empty( ::oParent:handle )
      ::handle := hwg_Createbrowse( ::oParent:handle, ::id, ;
         ::style, ::nLeft, ::nTop, ::nWidth, ::nHeight )
      ::Init()
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD onEvent( msg, wParam, lParam )  CLASS HBrowse

   LOCAL aCoors, oParent, cKeyb, nCtrl, nPos, iParHigh, iParLow

   // WriteLog( "Brw: "+Str(::handle,10)+"|"+Str(msg,6)+"|"+Str(wParam,10)+"|"+Str(lParam,10) )
   IF ::active .AND. !Empty( ::aColumns )

      IF ::bOther != Nil
         Eval( ::bOther, Self, msg, wParam, lParam )
      ENDIF

      IF msg == WM_PAINT
         ::Paint()
         RETURN 1

      ELSEIF msg == WM_ERASEBKGND
         IF ::brush != Nil
            aCoors := hwg_Getclientrect( ::handle )
            hwg_Fillrect( wParam, aCoors[1], aCoors[2], aCoors[3] + 1, aCoors[4] + 1, ::brush:handle )
            RETURN 1
         ENDIF

      ELSEIF msg == WM_SETFOCUS
         IF ::bGetFocus != Nil
            Eval( ::bGetFocus, Self )
            //::refreshLine()
         ENDIF

      ELSEIF msg == WM_KILLFOCUS
         IF ::bLostFocus != Nil
            Eval( ::bLostFocus, Self )
         ENDIF

      ELSEIF msg == WM_HSCROLL
         ::DoHScroll( wParam )

      ELSEIF msg == WM_VSCROLL
         ::DoVScroll( wParam )

      ELSEIF msg == WM_GETDLGCODE
         RETURN DLGC_WANTALLKEYS

      ELSEIF msg == WM_COMMAND
         IF ::aEvents != Nil
            iParHigh := hwg_Hiword( wParam )
            iParLow  := hwg_Loword( wParam )
            IF ( nPos := Ascan( ::aEvents, { |a|a[1] == iParHigh .AND. a[2] == iParLow } ) ) > 0
               Eval( ::aEvents[ nPos,3 ], Self, iParLow )
            ENDIF
         ENDIF

      ELSEIF msg == WM_KEYUP
         wParam := hwg_PtrToUlong( wParam )
         // inicio bloco sauli
         IF wParam == 17
            ::lCtrlPress := .F.
         ENDIF
         // fim bloco sauli
         RETURN 1

      ELSEIF msg == WM_KEYDOWN
         wParam := hwg_PtrToUlong( wParam )
         IF ::bKeyDown != Nil
            IF !Eval( ::bKeyDown, Self, wParam )
               RETURN 1
            ENDIF
         ENDIF
         IF wParam == 40        // Down
            ::LINEDOWN()
         ELSEIF wParam == 38    // Up
            ::LINEUP()
         ELSEIF wParam == 39    // Right
            ::DoHScroll( SB_LINERIGHT )
         ELSEIF wParam == 37    // Left
            ::DoHScroll( SB_LINELEFT )
         ELSEIF wParam == 36    // Home
            ::DoHScroll( SB_LEFT )
         ELSEIF wParam == 35    // End
            ::DoHScroll( SB_RIGHT )
         ELSEIF wParam == 34    // PageDown
            IF ::lCtrlPress
               ::BOTTOM()
            ELSE
               ::PageDown()
            ENDIF
         ELSEIF wParam == 33    // PageUp
            IF ::lCtrlPress
               ::TOP()
            ELSE
               ::PageUp()
            ENDIF
         ELSEIF wParam == 13    // Enter
            ::Edit()
            // inicio bloco sauli
         ELSEIF wParam == 17
            ::lCtrlPress := .T.
            // fim bloco sauli
         ELSEIF ::lAutoEdit .AND. ( wParam >= 48 .AND. wParam <= 90 .OR. wParam >= 96 .AND. wParam <= 111 )
            ::Edit( wParam, lParam )
         ENDIF
         RETURN 1

      ELSEIF msg == WM_LBUTTONDBLCLK
         ::ButtonDbl( lParam )

      ELSEIF msg == WM_LBUTTONDOWN
         ::ButtonDown( lParam )

      ELSEIF msg == WM_RBUTTONDOWN
         ::ButtonRDown( lParam )

      ELSEIF msg == WM_LBUTTONUP
         ::ButtonUp( lParam )

      ELSEIF msg == WM_MOUSEMOVE
         ::MouseMove( wParam, lParam )

      ELSEIF msg == WM_MOUSEWHEEL
         ::MouseWheel( hwg_Loword( wParam ), ;
            If( hwg_Hiword( wParam ) > 32768, ;
            hwg_Hiword( wParam ) - 65535, hwg_Hiword( wParam ) ), ;
            hwg_Loword( lParam ), hwg_Hiword( lParam ) )
      ELSEIF msg == WM_DESTROY
         ::End()
      ENDIF

   ENDIF

   RETURN - 1

   //----------------------------------------------------//

METHOD Init CLASS HBrowse

   IF !::lInit
      ::Super:Init()
      ::nHolder := 1
      hwg_Setwindowobject( ::handle, Self )
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD Redefine( lType, oWndParent, nId, oFont, bInit, bSize, bPaint, bEnter, bGfocus, bLfocus ) CLASS HBrowse

   ::Super:New( oWndParent, nId, 0, 0, 0, 0, 0, oFont, bInit, bSize, bPaint )

   ::type    := lType
   IF oFont == Nil
      ::oFont := ::oParent:oFont
   ENDIF
   ::bEnter  := bEnter
   ::bGetFocus  := bGFocus
   ::bLostFocus := bLFocus

   hwg_RegBrowse()
   ::InitBrw()

   RETURN Self

   //----------------------------------------------------//

METHOD FindBrowse( nId ) CLASS HBrowse

   LOCAL i := Ascan( ::aItemsList, { |o|o:id == nId }, 1, ::iItems )

   RETURN iif( i > 0, ::aItemsList[i], Nil )

   //----------------------------------------------------//

METHOD AddColumn( oColumn ) CLASS HBrowse

   LOCAL n, arr

   IF Valtype( oColumn ) == "A"
      arr := oColumn
      n := Len(arr)
      oColumn := HColumn():New( Iif(n>0,arr[1],Nil), Iif(n>1,arr[2],Nil), ;
         Iif(n>2,arr[3],Nil), Iif(n>3,arr[4],Nil), Iif(n>4,arr[5],Nil), Iif(n>5,arr[6],Nil) )
   ENDIF
   AAdd( ::aColumns, oColumn )
   ::lChanged := .T.
   InitColumn( Self, oColumn, Len( ::aColumns ) )

   RETURN oColumn

   //----------------------------------------------------//

METHOD InsColumn( oColumn, nPos ) CLASS HBrowse

   LOCAL n, arr

   IF Valtype( oColumn ) == "A"
      arr := oColumn
      n := Len(arr)
      oColumn := HColumn():New( Iif(n>0,arr[1],Nil), Iif(n>1,arr[2],Nil), ;
         Iif(n>2,arr[3],Nil), Iif(n>3,arr[4],Nil), Iif(n>4,arr[5],Nil), Iif(n>5,arr[6],Nil) )
   ENDIF
   AAdd( ::aColumns, Nil )
   AIns( ::aColumns, nPos )
   ::aColumns[ nPos ] := oColumn
   ::lChanged := .T.
   InitColumn( Self, oColumn, nPos )

   RETURN oColumn

STATIC FUNCTION InitColumn( oBrw, oColumn, n )

   IF oColumn:type == Nil
      oColumn:type := ValType( Eval( oColumn:block,,oBrw,n ) )
   ENDIF
   IF oColumn:dec == Nil
      IF oColumn:type == "N" .AND. At( '.', Str( Eval( oColumn:block,,oBrw,n ) ) ) != 0
         oColumn:dec := Len( SubStr( Str( Eval( oColumn:block,,oBrw,n ) ), ;
            At( '.', Str( Eval( oColumn:block,,oBrw,n ) ) ) + 1 ) )
      ELSE
         oColumn:dec := 0
      ENDIF
   ENDIF
   IF oColumn:length == Nil
      IF oColumn:picture != Nil
         oColumn:length := Len( Transform( Eval( oColumn:block,,oBrw,n ), oColumn:picture ) )
      ELSE
         oColumn:length := 10
      ENDIF
      oColumn:length := Max( oColumn:length, Len( oColumn:heading ) )
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD DelColumn( nPos ) CLASS HBrowse

   ADel( ::aColumns, nPos )
   ASize( ::aColumns, Len( ::aColumns ) - 1 )
   ::lChanged := .T.

   RETURN Nil

   //----------------------------------------------------//

METHOD End() CLASS HBrowse

   ::Super:End()
   IF ::brush != Nil
      ::brush:Release()
      ::brush := Nil
   ENDIF
   IF ::brushSel != Nil
      ::brushSel:Release()
      ::brushSel := Nil
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD InitBrw( nType )  CLASS HBrowse

   IF nType != Nil
      ::type := nType
   ELSE
      ::aColumns := {}
      ::rowPos    := ::nCurrent  := ::colpos := ::nLeftCol := 1
      ::freeze  := ::height := 0
      ::internal  := { 15, 1 }
      ::aArray     := Nil

      IF Empty( ColSizeCursor )
         ColSizeCursor := hwg_Loadcursor( IDC_SIZEWE )
         arrowCursor := hwg_Loadcursor( IDC_ARROW )
      ENDIF
   ENDIF

   IF ::type == BRW_DATABASE
      ::alias   := Alias()
      //Modified By Luiz Henrique dos Santos (luizhsantos@gmail.com.br)
      IF ::lFilter
         ::nLastRecordFilter  := ::nFirstRecordFilter := 0
         IF ::lDescend
            ::bSkip     := { |o, n| ( ::alias ) -> ( FltSkip( o, n, .T. ) ) }
            ::bGoTop    := { |o| ( ::alias ) -> ( FltGoBottom( o ) ) }
            ::bGoBot    := { |o| ( ::alias ) -> ( FltGoTop( o ) ) }
            ::bEof      := { |o| ( ::alias ) -> ( FltBOF( o ) ) }
            ::bBof      := { |o| ( ::alias ) -> ( FltEOF( o ) ) }
         ELSE
            ::bSkip     := { |o, n| ( ::alias ) -> ( FltSkip( o, n, .F. ) ) }
            ::bGoTop    := { |o| ( ::alias ) -> ( FltGoTop( o ) ) }
            ::bGoBot    := { |o| ( ::alias ) -> ( FltGoBottom( o ) ) }
            ::bEof      := { |o| ( ::alias ) -> ( FltEOF( o ) ) }
            ::bBof      := { |o| ( ::alias ) -> ( FltBOF( o ) ) }
         ENDIF
         ::bRcou     := { |o| ( ::alias ) -> ( FltRecCount( o ) ) }
         ::bRecnoLog := ::bRecno := { |o| ( ::alias ) -> ( FltRecNo( o ) ) }
         ::bGoTo     := { |o, n|( ::alias ) -> ( FltGoTo( o, n ) ) }
      ELSE
         ::bSkip     :=  { |o, n| ( ::alias ) -> ( dbSkip( n ) ) }
         ::bGoTop    :=  { || ( ::alias ) -> ( DBGOTOP() ) }
         ::bGoBot    :=  { || ( ::alias ) -> ( dbGoBottom() ) }
         ::bEof      :=  { || ( ::alias ) -> ( Eof() ) }
         ::bBof      :=  { || ( ::alias ) -> ( Bof() ) }
         ::bRcou     :=  { || ( ::alias ) -> ( RecCount() ) }
         ::bRecnoLog := ::bRecno  := { ||( ::alias ) -> ( RecNo() ) }
         ::bGoTo     := { |a, n|( ::alias ) -> ( dbGoto( n ) ) }
      ENDIF
   ELSEIF ::type == BRW_ARRAY
      ::bSkip      := { | o, n | ARSKIP( o, n ) }
      ::bGoTop  := { | o | o:nCurrent := 1 }
      ::bGoBot  := { | o | o:nCurrent := o:nRecords }
      ::bEof    := { | o | o:nCurrent > o:nRecords }
      ::bBof    := { | o | o:nCurrent == 0 }
      ::bRcou   := { | o | Len( o:aArray ) }
      ::bRecnoLog := ::bRecno  := { | o | o:nCurrent }
      ::bGoTo   := { | o, n | o:nCurrent := n }
      ::bScrollPos := { |o, n, lEof, nPos|hwg_VScrollPos( o, n, lEof, nPos ) }
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD Rebuild( hDC ) CLASS HBrowse

   LOCAL i, j, oColumn, xSize, nColLen, nHdrLen, nCount

   IF ::brush != Nil
      ::brush:Release()
   ENDIF
   IF ::brushSel != Nil
      ::brushSel:Release()
   ENDIF
   IF ::bcolor != Nil
      ::brush     := HBrush():Add( ::bcolor )
      IF hDC != Nil
         hwg_Sendmessage( ::handle, WM_ERASEBKGND, hDC, 0 )
      ENDIF
   ENDIF
   IF ::bcolorSel != Nil
      ::brushSel  := HBrush():Add( ::bcolorSel )
   ENDIF
   ::nLeftCol  := ::freeze + 1
   // ::nCurrent     := ::rowPos := ::colPos := 1
   ::lEditable := .F.

   ::minHeight := 0
   FOR i := 1 TO Len( ::aColumns )

      oColumn := ::aColumns[i]

      IF oColumn:lEditable
         ::lEditable := .T.
      ENDIF

      IF oColumn:aBitmaps != Nil
         xSize := 0
         FOR j := 1 TO Len( oColumn:aBitmaps )
            IF Valtype( oColumn:aBitmaps[j,2] ) == "O"
               xSize := Max( xSize, oColumn:aBitmaps[j,2]:nWidth + 2 )
               ::minHeight := Max( ::minHeight, oColumn:aBitmaps[j,2]:nHeight )
            ENDIF
         NEXT
      ELSE
         // xSize := round( (max( len( FldStr( Self,i ) ), len( oColumn:heading ) ) + 2 ) * 8, 0 )
         nColLen := oColumn:length
         IF oColumn:heading != nil
            HdrToken( oColumn:heading, @nHdrLen, @nCount )
            IF ! oColumn:lSpandHead
               nColLen := Max( nColLen, nHdrLen )
            ENDIF
            ::nHeadRows := Max( ::nHeadRows, nCount )
         ENDIF
         IF oColumn:footing != nil
            HdrToken( oColumn:footing, @nHdrLen, @nCount )
            IF ! oColumn:lSpandFoot
               nColLen := Max( nColLen, nHdrLen )
            ENDIF
            ::nFootRows := Max( ::nFootRows, nCount )
         ENDIF
         xSize := Round( ( nColLen ) * hwg_GetTextMetric(hDC)[2], 0 )
         //hwg_writelog( str(i)+":"+str(xsize)+"/"+str(nColLen)+"/"+Str(hwg_GetTextMetric(hDC)[2]) )
      ENDIF

      oColumn:width := xSize

   NEXT

   ::lChanged := .F.

   RETURN Nil

   //----------------------------------------------------//

METHOD Paint( lLostFocus )  CLASS HBrowse

   LOCAL aCoors, aMetr, i, oldAlias, tmp, nRows
   LOCAL pps, hDC
   LOCAL oldBkColor, oldTColor

   IF !::active .OR. Empty( ::aColumns )
      pps := hwg_Definepaintstru()
      hDC := hwg_Beginpaint( ::handle, pps )
      hwg_Endpaint( ::handle, pps )
      RETURN Nil
   ENDIF

   IF ::tcolor    == Nil ; ::tcolor    := 0 ; ENDIF
   IF ::bcolor    == Nil ; ::bcolor    := hwg_VColor( "FFFFFF" ) ; ENDIF

   IF ::httcolor  == Nil ; ::httcolor  := hwg_VColor( "FFFFFF" ) ; ENDIF
   IF ::htbcolor  == Nil ; ::htbcolor  := 2896388  ; ENDIF

   IF ::tcolorSel == Nil ; ::tcolorSel := hwg_VColor( "FFFFFF" ) ; ENDIF
   IF ::bcolorSel == Nil ; ::bcolorSel := hwg_VColor( "808080" ) ; ENDIF

   pps := hwg_Definepaintstru()
   hDC := hwg_Beginpaint( ::handle, pps )

   IF ::ofont != Nil
      hwg_Selectobject( hDC, ::ofont:handle )
   ENDIF
   IF ::brush == Nil .OR. ::lChanged
      ::Rebuild( hDC )
   ENDIF
   aCoors := hwg_Getclientrect( ::handle )
   aMetr := hwg_Gettextmetric( hDC )
   ::width := Round( ( aMetr[ 3 ] + aMetr[ 2 ] ) / 2 - 1, 0 )
   ::height := Max( aMetr[ 1 ], ::minHeight ) + 1
   ::x1 := aCoors[ 1 ]
   ::y1 := aCoors[ 2 ] + iif( ::lDispHead, ::height * ::nHeadRows, 0 )
   ::x2 := aCoors[ 3 ]
   ::y2 := aCoors[ 4 ]

   ::nRecords := Eval( ::bRcou, Self )
   IF ::nCurrent > ::nRecords .AND. ::nRecords > 0
      ::nCurrent := ::nRecords
   ENDIF

   ::nColumns := FLDCOUNT( Self, ::x1 + 2, ::x2 - 2, ::nLeftCol )
   ::rowCount := Int( ( ::y2 - ::y1 ) / ( ::height + 1 ) ) - ::nFootRows
   nRows := Min( ::nRecords, ::rowCount )

   IF ::internal[1] == 0
      IF ::rowPos != ::internal[2] .AND. !::lAppMode
         Eval( ::bSkip, Self, ::internal[2] - ::rowPos )
      ENDIF
      IF ::aSelected != Nil .AND. Ascan( ::aSelected, { |x| x = Eval( ::bRecno,Self ) } ) > 0
         ::LineOut( ::internal[2], 0, hDC, .T. )
      ELSE
         ::LineOut( ::internal[2], 0, hDC, .F. )
      ENDIF
      IF ::rowPos != ::internal[2] .AND. !::lAppMode
         Eval( ::bSkip, Self, ::rowPos - ::internal[2] )
      ENDIF
   ELSE
      // Modified by Luiz Henrique dos Santos (luizhsantos@gmail.com)
      //IF Eval( ::bEof,Self )
      IF Eval( ::bEof, Self ) .OR. Eval( ::bBof, Self )
         Eval( ::bGoTop, Self )
         ::rowPos := 1
      ENDIF
      IF ::rowPos > nRows .AND. nRows > 0
         ::rowPos := nRows
      ENDIF
      tmp := Eval( ::bRecno, Self )
      IF ::rowPos > 1
         Eval( ::bSkip, Self, - ( ::rowPos - 1 ) )
      ENDIF
      i := 1
      DO WHILE .T.
         IF Eval( ::bRecno, Self ) == tmp
            ::rowPos := i
         ENDIF
         IF i > nRows .OR. Eval( ::bEof, Self )
            EXIT
         ENDIF
         IF ::aSelected != Nil .AND. Ascan( ::aSelected, { |x| x = Eval( ::bRecno,Self ) } ) > 0
            ::LineOut( i, 0, hDC, .T. )
         ELSE
            ::LineOut( i, 0, hDC, .F. )
         ENDIF
         i ++
         Eval( ::bSkip, Self, 1 )
      ENDDO
      ::rowCurrCount := i - 1

      IF ::rowPos >= i
         ::rowPos := iif( i > 1, i - 1, 1 )
      ENDIF
      DO WHILE i <= nRows
         IF ::aSelected != Nil .AND. Ascan( ::aSelected, { |x| x = Eval( ::bRecno,Self ) } ) > 0
            ::LineOut( i, 0, hDC, .T. , .T. )
         ELSE
            ::LineOut( i, 0, hDC, .F. , .T. )
         ENDIF
         i ++
      ENDDO

      Eval( ::bGoTo, Self, tmp )
   ENDIF
   IF ::lAppMode
      ::LineOut( nRows + 1, 0, hDC, .F. , .T. )
   ENDIF

   //::LineOut( ::rowPos, Iif( ::lEditable, ::colpos, 0 ), hDC, .T. )
   ::LineOut( ::rowPos, 0, hDC, .T. )
   //if ::lEditable
   IF lLostFocus == NIL
      ::LineOut( ::rowPos, ::colpos, hDC, .T. )
   ENDIF
   //endif

   IF hwg_Checkbit( ::internal[1], 1 ) .OR. ::lAppMode
      ::HeaderOut( hDC )
      IF ::nFootRows > 0
         ::FooterOut( hDC )
      ENDIF
   ENDIF

   hwg_Endpaint( ::handle, pps )
   ::internal[1] := 15
   ::internal[2] := ::rowPos
   tmp := Eval( ::bRecno, Self )
   IF ::recCurr != tmp
      ::recCurr := tmp
      IF ::bPosChanged != Nil
         Eval( ::bPosChanged, Self )
      ENDIF
   ENDIF

   IF ::lAppMode
      ::Edit()
   ENDIF

   IF ::lInFocus .AND. ( ( tmp := hwg_Getfocus() ) == ::oParent:handle ;
         .OR. ::oParent:FindControl(,tmp) != Nil )
      hwg_Setfocus( ::handle )
   ENDIF

   ::lAppMode := .F.

   RETURN Nil

   //----------------------------------------------------//

METHOD HeaderOut( hDC ) CLASS HBrowse

   LOCAL i, x, oldc, fif, xSize
   LOCAL nRows := Min( ::nRecords + iif( ::lAppMode,1,0 ), ::rowCount )
   LOCAL oPen, oldBkColor := hwg_Setbkcolor( hDC, hwg_Getsyscolor( COLOR_3DFACE ) )
   LOCAL oColumn, nLine, cStr, cNWSE, oPenHdr, oPenLight

   IF ::lDispSep
      oPen := HPen():Add( PS_SOLID, 1, ::sepColor )
      hwg_Selectobject( hDC, oPen:handle )
   ENDIF
   IF ::lSep3d
      oPenLight := HPen():Add( PS_SOLID, 1, hwg_Getsyscolor( COLOR_3DHILIGHT ) )
   ENDIF

   x := ::x1
   IF ::headColor <> Nil
      oldc := hwg_Settextcolor( hDC, ::headColor )
   ENDIF
   fif := iif( ::freeze > 0, 1, ::nLeftCol )

   DO WHILE x < ::x2 - 2
      oColumn := ::aColumns[fif]
      xSize := oColumn:width
      IF ::lAdjRight .AND. fif == Len( ::aColumns )
         xSize := Max( ::x2 - x, xSize )
      ENDIF
      IF ::lDispHead .AND. !::lAppMode
         IF oColumn:cGrid == nil
            hwg_Drawbutton( hDC, x - 1, ::y1 - ::height * ::nHeadRows, x + xSize - 1, ::y1 + 1, 1 )
         ELSE
            hwg_Drawbutton( hDC, x - 1, ::y1 - ::height * ::nHeadRows, x + xSize - 1, ::y1 + 1, 0 )
            IF oPenHdr == nil
               oPenHdr := HPen():Add( BS_SOLID, 1, 0 )
            ENDIF
            hwg_Selectobject( hDC, oPenHdr:handle )
            cStr := oColumn:cGrid + ';'
            FOR nLine := 1 TO ::nHeadRows
               cNWSE := hb_tokenGet( @cStr, nLine, ';' )
               IF At( 'S', cNWSE ) != 0
                  hwg_Drawline( hDC, x - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine ), x + xSize - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine ) )
               ENDIF
               IF At( 'N', cNWSE ) != 0
                  hwg_Drawline( hDC, x - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine + 1 ), x + xSize - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine + 1 ) )
               ENDIF
               IF At( 'E', cNWSE ) != 0
                  hwg_Drawline( hDC, x + xSize - 2, ::y1 - ( ::height ) * ( ::nHeadRows - nLine + 1 ) + 1, x + xSize - 2, ::y1 - ( ::height ) * ( ::nHeadRows - nLine ) )
               ENDIF
               IF At( 'W', cNWSE ) != 0
                  hwg_Drawline( hDC, x - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine + 1 ) + 1, x - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine ) )
               ENDIF
            NEXT
            hwg_Selectobject( hDC, oPen:handle )
         ENDIF
         // Ahora Titulos Justificados !!!
         cStr := oColumn:heading + ';'
         FOR nLine := 1 TO ::nHeadRows
            hwg_Drawtext( hDC, hb_tokenGet( @cStr, nLine, ';' ), x, ::y1 - ( ::height ) * ( ::nHeadRows - nLine + 1 ) + 1, x + xSize - 1, ::y1 - ( ::height ) * ( ::nHeadRows - nLine ), ;
               oColumn:nJusHead  + if( oColumn:lSpandHead, DT_NOCLIP, 0 ) )
         NEXT
      ENDIF
      IF ::lDispSep .AND. x > ::x1
         IF ::lSep3d
            hwg_Selectobject( hDC, oPenLight:handle )
            hwg_Drawline( hDC, x - 1, ::y1 + 1, x - 1, ::y1 + ( ::height + 1 ) * nRows )
            hwg_Selectobject( hDC, oPen:handle )
            hwg_Drawline( hDC, x - 2, ::y1 + 1, x - 2, ::y1 + ( ::height + 1 ) * nRows )
         ELSE
            hwg_Drawline( hDC, x - 1, ::y1 + 1, x - 1, ::y1 + ( ::height + 1 ) * nRows )
         ENDIF
      ENDIF
      x += xSize
      IF ! ::lAdjRight .AND. fif == Len( ::aColumns )
         hwg_Drawline( hDC, x - 1, ::y1 - ( ::height * ::nHeadRows ), x - 1, ::y1 + ( ::height + 1 ) * nRows )
      ENDIF
      fif := iif( fif = ::freeze, ::nLeftCol, fif + 1 )
      IF fif > Len( ::aColumns )
         EXIT
      ENDIF
   ENDDO

   IF ::lDispSep
      FOR i := 1 TO nRows
         hwg_Drawline( hDC, ::x1, ::y1 + ( ::height + 1 ) * i, iif( ::lAdjRight, ::x2, x ), ::y1 + ( ::height + 1 ) * i )
      NEXT
   ENDIF

   hwg_Setbkcolor( hDC, oldBkColor )
   IF ::headColor <> Nil
      hwg_Settextcolor( hDC, oldc )
   ENDIF
   IF ::lDispSep
      oPen:Release()
      IF oPenHdr != nil
         oPenHdr:Release()
      ENDIF
      IF oPenLight != nil
         oPenLight:Release()
      ENDIF
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD FooterOut( hDC ) CLASS HBrowse

   LOCAL i, x, fif, xSize, oPen, nLine, cStr
   LOCAL oColumn

   IF ::lDispSep
      oPen := HPen():Add( BS_SOLID, 1, ::sepColor )
      hwg_Selectobject( hDC, oPen:handle )
   ENDIF

   x := ::x1
   fif := iif( ::freeze > 0, 1, ::nLeftCol )

   DO WHILE x < ::x2 - 2
      oColumn := ::aColumns[fif]
      xSize := oColumn:width
      IF ::lAdjRight .AND. fif == Len( ::aColumns )
         xSize := Max( ::x2 - x, xSize )
      ENDIF
      IF oColumn:footing <> nil
         cStr := oColumn:footing + ';'
         FOR nLine := 1 TO ::nFootRows
            hwg_Drawtext( hDC, hb_tokenGet( @cStr, nLine, ';' ), ;
               x, ::y1 + ( ::rowCount + nLine - 1 ) * ( ::height + 1 ) + 1, x + xSize - 1, ::y1 + ( ::rowCount + nLine ) * ( ::height + 1 ), ;
               oColumn:nJusLin + if( oColumn:lSpandFoot, DT_NOCLIP, 0 ) )
         NEXT
      ENDIF
      x += xSize
      fif := iif( fif = ::freeze, ::nLeftCol, fif + 1 )
      IF fif > Len( ::aColumns )
         EXIT
      ENDIF
   ENDDO

   IF ::lDispSep
      hwg_Drawline( hDC, ::x1, ::y1 + ( ::rowCount ) * ( ::height + 1 ) + 1, iif( ::lAdjRight, ::x2, x ), ::y1 + ( ::rowCount ) * ( ::height + 1 ) + 1 )
      oPen:Release()
   ENDIF

   RETURN Nil

   //-------------- -Row--  --Col-- ------------------------------//

METHOD LineOut( nstroka, vybfld, hDC, lSelected, lClear ) CLASS HBrowse

   LOCAL x, dx, i := 1, shablon, sviv, fldname, slen, xSize
   LOCAL j, ob, bw, bh, y1, hBReal
   LOCAL oldBkColor, oldTColor, oldBk1Color, oldT1Color
   LOCAL oLineBrush :=  iif( vybfld >= 1, HBrush():Add( ::htbColor ), iif( lSelected, ::brushSel,::brush ) )
   LOCAL lColumnFont := .F.

   //Local nPaintCol, nPaintRow
   LOCAL aCores

   ::xpos := x := ::x1
   IF lClear == Nil ; lClear := .F. ; ENDIF

   IF ::bLineOut != Nil
      Eval( ::bLineOut, Self, lSelected )
   ENDIF
   IF ::nRecords > 0
      oldBkColor := hwg_Setbkcolor(   hDC, iif( vybfld >= 1,::htbcolor, iif( lSelected,::bcolorSel,::bcolor ) ) )
      oldTColor  := hwg_Settextcolor( hDC, iif( vybfld >= 1,::httcolor, iif( lSelected,::tcolorSel,::tcolor ) ) )
      fldname := Space( 8 )
      ::nPaintCol  := iif( ::freeze > 0, 1, ::nLeftCol )
      ::nPaintRow  := nstroka

      WHILE x < ::x2 - 2
         IF ::aColumns[::nPaintCol]:bColorBlock != Nil
            aCores := Eval( ::aColumns[::nPaintCol]:bColorBlock )
            IF lSelected
               ::aColumns[::nPaintCol]:tColor := aCores[3]
               ::aColumns[::nPaintCol]:bColor := aCores[4]
            ELSE
               ::aColumns[::nPaintCol]:tColor := aCores[1]
               ::aColumns[::nPaintCol]:bColor := aCores[2]
            ENDIF
            ::aColumns[::nPaintCol]:brush := HBrush():Add( ::aColumns[::nPaintCol]:bColor   )
         ENDIF
         xSize := ::aColumns[::nPaintCol]:width
         IF ::lAdjRight .AND. ::nPaintCol == Len( ::aColumns )
            xSize := Max( ::x2 - x, xSize )
         ENDIF
         IF i == ::colpos
            ::xpos := x
         ENDIF

         IF vybfld == 0 .OR. vybfld == i
            IF ::aColumns[::nPaintCol]:bColor != Nil .AND. ::aColumns[::nPaintCol]:brush == Nil
               ::aColumns[::nPaintCol]:brush := HBrush():Add( ::aColumns[::nPaintCol]:bColor )
            ENDIF
            hBReal := iif( ::aColumns[::nPaintCol]:brush != Nil, ;
               ::aColumns[::nPaintCol]:brush:handle,   ;
               oLineBrush:handle )
            hwg_Fillrect( hDC, x, ::y1 + ( ::height + 1 ) * ( ::nPaintRow - 1 ) + 1, x + xSize - iif( ::lSep3d,2,1 ), ::y1 + ( ::height + 1 ) * ::nPaintRow, hBReal )

            IF !lClear
               IF ::aColumns[::nPaintCol]:aBitmaps != Nil .AND. !Empty( ::aColumns[::nPaintCol]:aBitmaps )
                  FOR j := 1 TO Len( ::aColumns[::nPaintCol]:aBitmaps )
                     IF Eval( ::aColumns[::nPaintCol]:aBitmaps[j,1], Eval( ::aColumns[::nPaintCol]:block,,Self,::nPaintCol ), lSelected )                       
                        IF !Empty( ob := ::aColumns[::nPaintCol]:aBitmaps[j,2] )
                           IF ob:nHeight > ::height
                              y1 := 0
                              bh := ::height
                              bw := Int( ob:nWidth * ( ob:nHeight / ::height ) )
                              hwg_Drawbitmap( hDC, ob:handle, , x, y1 + ::y1 + ( ::height + 1 ) * ( ::nPaintRow - 1 ) + 1, bw, bh )
                           ELSE
                              y1 := Int( ( ::height - ob:nHeight )/2 )
                              bh := ob:nHeight
                              bw := ob:nWidth
                              hwg_Drawtransparentbitmap( hDC, ob:handle, x, y1 + ::y1 + ( ::height + 1 ) * ( ::nPaintRow - 1 ) + 1 )
                           ENDIF
                        ENDIF
                        EXIT
                     ENDIF
                  NEXT
               ELSE
                  sviv := FLDSTR( Self, ::nPaintCol )
                  // Ahora lineas Justificadas !!
                  IF ::aColumns[::nPaintCol]:tColor != Nil
                     oldT1Color := hwg_Settextcolor( hDC, ::aColumns[::nPaintCol]:tColor )
                  ENDIF

                  IF ::aColumns[::nPaintCol]:bColor != Nil
                     oldBk1Color := hwg_Setbkcolor( hDC, ::aColumns[::nPaintCol]:bColor )
                  ENDIF
                  IF ::aColumns[::nPaintCol]:oFont != Nil
                     hwg_Selectobject( hDC, ::aColumns[::nPaintCol]:oFont:handle )
                     lColumnFont := .T.
                  ELSEIF lColumnFont
                     hwg_Selectobject( hDC, ::ofont:handle )
                     lColumnFont := .F.
                  ENDIF

                  hwg_Drawtext( hDC, sviv, x, ::y1 + ( ::height + 1 ) * ( ::nPaintRow - 1 ) + 1, x + xSize - 2, ::y1 + ( ::height + 1 ) * ::nPaintRow - 1, ::aColumns[::nPaintCol]:nJusLin )

                  IF ::aColumns[::nPaintCol]:tColor != Nil
                     hwg_Settextcolor( hDC, oldT1Color )
                  ENDIF

                  IF ::aColumns[::nPaintCol]:bColor != Nil
                     hwg_Setbkcolor( hDC, oldBk1Color )
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
         x += xSize
         ::nPaintCol := iif( ::nPaintCol == ::freeze, ::nLeftCol, ::nPaintCol + 1 )
         i ++
         IF ! ::lAdjRight .AND. ::nPaintCol > Len( ::aColumns )
            EXIT
         ENDIF
      ENDDO
      hwg_Settextcolor( hDC, oldTColor )
      hwg_Setbkcolor( hDC, oldBkColor )
      IF lColumnFont
         hwg_Selectobject( hDC, ::ofont:handle )
      ENDIF
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD SetColumn( nCol ) CLASS HBrowse

   LOCAL nColPos, lPaint := .F.

   IF ::lEditable
      IF nCol != nil .AND. nCol >= 1 .AND. nCol <= Len( ::aColumns )
         IF nCol <= ::freeze
            ::colpos := nCol
         ELSEIF nCol >= ::nLeftCol .AND. nCol <= ::nLeftCol + ::nColumns - ::freeze - 1
            ::colpos := nCol - ::nLeftCol + ::freeze + 1
         ELSE
            ::nLeftCol := nCol
            ::colpos := ::freeze + 1
            lPaint := .T.
         ENDIF
         IF !lPaint
            ::RefreshLine()
         ELSE
            hwg_Redrawwindow( ::handle, RDW_ERASE + RDW_INVALIDATE )
         ENDIF
      ENDIF

      IF ::colpos <= ::freeze
         nColPos := ::colpos
      ELSE
         nColPos := ::nLeftCol + ::colpos - ::freeze - 1
      ENDIF
      RETURN nColPos

   ENDIF

   RETURN 1

   //----------------------------------------------------//

STATIC FUNCTION LINERIGHT( oBrw )

   LOCAL i

   IF oBrw:lEditable
      IF oBrw:colpos < oBrw:nColumns
         oBrw:colpos ++
         RETURN Nil
      ENDIF
   ENDIF
   IF oBrw:nColumns + oBrw:nLeftCol - oBrw:freeze - 1 < Len( oBrw:aColumns ) ;
         .AND. oBrw:nLeftCol < Len( oBrw:aColumns )
      i := oBrw:nLeftCol + oBrw:nColumns
      DO WHILE oBrw:nColumns + oBrw:nLeftCol - oBrw:freeze - 1 < Len( oBrw:aColumns ) .AND. oBrw:nLeftCol + oBrw:nColumns = i
         oBrw:nLeftCol ++
      ENDDO
      oBrw:colpos := i - oBrw:nLeftCol + 1
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

STATIC FUNCTION LINELEFT( oBrw )

   IF oBrw:lEditable
      oBrw:colpos --
   ENDIF
   IF oBrw:nLeftCol > oBrw:freeze + 1 .AND. ( !oBrw:lEditable .OR. oBrw:colpos < oBrw:freeze + 1 )
      oBrw:nLeftCol --
      IF ! oBrw:lEditable .OR. oBrw:colpos < oBrw:freeze + 1
         oBrw:colpos := oBrw:freeze + 1
      ENDIF
   ENDIF
   IF oBrw:colpos < 1
      oBrw:colpos := 1
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD DoVScroll( wParam ) CLASS HBrowse

   LOCAL nScrollCode := hwg_Loword( wParam )

   IF nScrollCode == SB_LINEDOWN
      ::LINEDOWN( .T. )
   ELSEIF nScrollCode == SB_LINEUP
      ::LINEUP()
   ELSEIF nScrollCode == SB_BOTTOM
      ::BOTTOM()
   ELSEIF nScrollCode == SB_TOP
      ::TOP()
   ELSEIF nScrollCode == SB_PAGEDOWN
      ::PAGEDOWN()
   ELSEIF nScrollCode == SB_PAGEUP
      ::PAGEUP()

   ELSEIF nScrollCode == SB_THUMBPOSITION
      IF ::bScrollPos != Nil
         Eval( ::bScrollPos, Self, SB_THUMBPOSITION, .F. , hwg_Hiword( wParam ) )
      ENDIF
   ELSEIF nScrollCode == SB_THUMBTRACK
      IF ::bScrollPos != Nil
         Eval( ::bScrollPos, Self, SB_THUMBTRACK, .F. , hwg_Hiword( wParam ) )
      ENDIF
   ENDIF

   RETURN 0

   //----------------------------------------------------//

METHOD DoHScroll( wParam ) CLASS HBrowse

   LOCAL nScrollCode := hwg_Loword( wParam )
   LOCAL minPos, maxPos, nPos
   LOCAL oldLeft := ::nLeftCol, nLeftCol, colpos, oldPos := ::colpos, fif
   LOCAL lMoveThumb := .T.

   hwg_Getscrollrange( ::handle, SB_HORZ, @minPos, @maxPos )
   //nPos := hwg_Getscrollpos( ::handle, SB_HORZ )

   IF nScrollCode == SB_LINELEFT .OR. nScrollCode == SB_PAGELEFT
      LineLeft( Self )

   ELSEIF nScrollCode == SB_LINERIGHT .OR. nScrollCode == SB_PAGERIGHT
      LineRight( Self )

   ELSEIF nScrollCode == SB_LEFT
      nLeftCol := colPos := 0
      DO WHILE nLeftCol != ::nLeftCol .OR. colPos != ::colPos
         nLeftCol := ::nLeftCol
         colPos := ::colPos
         LineLeft( Self )
      ENDDO
   ELSEIF nScrollCode == SB_RIGHT
      nLeftCol := colPos := 0
      DO WHILE nLeftCol != ::nLeftCol .OR. colPos != ::colPos
         nLeftCol := ::nLeftCol
         colPos := ::colPos
         LineRight( Self )
      ENDDO
   ELSEIF nScrollCode == SB_THUMBPOSITION
      IF ::bHScrollPos != Nil
         Eval( ::bHScrollPos, Self, SB_THUMBPOSITION, .F. , hwg_Hiword( wParam ) )
         lMoveThumb := .F.
      ENDIF

   ELSEIF nScrollCode == SB_THUMBTRACK
      IF ::bHScrollPos != Nil
         Eval( ::bHScrollPos, Self, SB_THUMBTRACK, .F. , hwg_Hiword( wParam ) )
         lMoveThumb := .F.
      ENDIF
   ENDIF

   IF ::nLeftCol != oldLeft .OR. ::colpos != oldpos

      /* Move scrollbar thumb if ::bHScrollPos has not been called, since, in this case,
         movement of scrollbar thumb is done by that codeblock
      */
      IF lMoveThumb

         fif := iif( ::lEditable, ::colpos + ::nLeftCol - 1, ::nLeftCol )
         nPos := iif( fif == 1, minPos,                        ;
            iif( fif = Len( ::aColumns ), maxpos,      ;
            Int( ( maxPos - minPos + 1 ) * fif / Len( ::aColumns ) ) ) )
         hwg_Setscrollpos( ::handle, SB_HORZ, nPos )

      ENDIF

      IF ::nLeftCol == oldLeft
         ::RefreshLine()
      ELSE
         hwg_Redrawwindow( ::handle, RDW_ERASE + RDW_INVALIDATE )
      ENDIF
   ENDIF
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD LINEDOWN( lMouse ) CLASS HBrowse

   LOCAL minPos, maxPos, nPos

   Eval( ::bSkip, Self, 1 )
   IF Eval( ::bEof, Self )
      Eval( ::bSkip, Self, - 1 )
      IF ::lAppable .AND. ( lMouse == Nil .OR. !lMouse )
         ::lAppMode := .T.
      ELSE
         hwg_Setfocus( ::handle )
         RETURN Nil
      ENDIF
   ENDIF
   ::rowPos ++
   IF ::rowPos > ::rowCount
      ::rowPos := ::rowCount
      hwg_Invalidaterect( ::handle, 0 )
   ELSE
      ::internal[1] := 0
      hwg_Invalidaterect( ::handle, 0, ::x1, ::y1 + ( ::height + 1 ) * ::internal[2] - ::height, ::x2, ::y1 + ( ::height + 1 ) * ( ::rowPos + 1 ) )
   ENDIF
   IF ::lAppMode
      IF ::rowPos > 1
         ::rowPos --
      ENDIF
      ::colPos := ::nLeftCol := 1
   ENDIF
   IF !::lAppMode  .OR. ::nLeftCol == 1
      ::internal[1] := hwg_Setbit( ::internal[1], 1, 0 )
   ENDIF

   IF ::bScrollPos != Nil
      Eval( ::bScrollPos, Self, 1, .F. )
   ELSEIF ::nRecords > 1
      hwg_Getscrollrange( ::handle, SB_VERT, @minPos, @maxPos )
      nPos := hwg_Getscrollpos( ::handle, SB_VERT )
      nPos += Int( ( maxPos - minPos )/ (::nRecords - 1 ) )
      hwg_Setscrollpos( ::handle, SB_VERT, nPos )
   ENDIF

   hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD LINEUP() CLASS HBrowse

   LOCAL minPos, maxPos, nPos

   Eval( ::bSkip, Self, - 1 )
   IF Eval( ::bBof, Self )
      Eval( ::bGoTop, Self )
   ELSE
      ::rowPos --
      IF ::rowPos = 0
         ::rowPos := 1
         hwg_Invalidaterect( ::handle, 0 )
      ELSE
         ::internal[1] := 0
         hwg_Invalidaterect( ::handle, 0, ::x1, ::y1 + ( ::height + 1 ) * ::internal[2] - ::height, ::x2, ::y1 + ( ::height + 1 ) * ::internal[2] )
         hwg_Invalidaterect( ::handle, 0, ::x1, ::y1 + ( ::height + 1 ) * ::rowPos - ::height, ::x2, ::y1 + ( ::height + 1 ) * ::rowPos )
      ENDIF

      IF ::bScrollPos != Nil
         Eval( ::bScrollPos, Self, - 1, .F. )
      ELSEIF ::nRecords > 1
         hwg_Getscrollrange( ::handle, SB_VERT, @minPos, @maxPos )
         nPos := hwg_Getscrollpos( ::handle, SB_VERT )
         nPos -= Int( ( maxPos - minPos )/ (::nRecords - 1 ) )
         hwg_Setscrollpos( ::handle, SB_VERT, nPos )
      ENDIF
      ::internal[1] := hwg_Setbit( ::internal[1], 1, 0 )
      hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
   ENDIF
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD PAGEUP() CLASS HBrowse

   LOCAL minPos, maxPos, nPos, step, lBof := .F.

   IF ::rowPos > 1
      step := ( ::rowPos - 1 )
      Eval( ::bSKip, Self, - step )
      ::rowPos := 1
   ELSE
      step := ::rowCurrCount    // Min( ::nRecords,::rowCount )
      Eval( ::bSkip, Self, - step )
      IF Eval( ::bBof, Self )
         Eval( ::bGoTop, Self )
         lBof := .T.
      ENDIF
   ENDIF

   IF ::bScrollPos != Nil
      Eval( ::bScrollPos, Self, - step, lBof )
   ELSEIF ::nRecords > 1
      hwg_Getscrollrange( ::handle, SB_VERT, @minPos, @maxPos )
      nPos := hwg_Getscrollpos( ::handle, SB_VERT )
      nPos := Max( nPos - Int( (maxPos - minPos ) * step/(::nRecords - 1 ) ), minPos )
      hwg_Setscrollpos( ::handle, SB_VERT, nPos )
   ENDIF

   ::Refresh( .F. )
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD PAGEDOWN() CLASS HBrowse

   LOCAL minPos, maxPos, nPos, nRows := ::rowCurrCount
   LOCAL step := iif( nRows > ::rowPos, nRows - ::rowPos + 1, nRows )

   Eval( ::bSkip, Self, step )
   ::rowPos := Min( ::nRecords, nRows )

   IF ::bScrollPos != Nil
      Eval( ::bScrollPos, Self, step, Eval( ::bEof,Self ) )
   ELSE
      hwg_Getscrollrange( ::handle, SB_VERT, @minPos, @maxPos )
      nPos := hwg_Getscrollpos( ::handle, SB_VERT )
      IF Eval( ::bEof, Self )
         Eval( ::bSkip, Self, - 1 )
         nPos := maxPos
         hwg_Setscrollpos( ::handle, SB_VERT, nPos )
      ELSEIF ::nRecords > 1
         nPos := Min( nPos + Int( (maxPos - minPos ) * step/(::nRecords - 1 ) ), maxPos )
         hwg_Setscrollpos( ::handle, SB_VERT, nPos )
      ENDIF

   ENDIF

   ::Refresh( .F. )
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD BOTTOM( lPaint ) CLASS HBrowse

   LOCAL minPos, maxPos, nPos

   hwg_Getscrollrange( ::handle, SB_VERT, @minPos, @maxPos )

   nPos := hwg_Getscrollpos( ::handle, SB_VERT )
   ::rowPos := LastRec()
   Eval( ::bGoBot, Self )
   ::rowPos := Min( ::nRecords, ::rowCount )
   nPos := maxPos
   hwg_Setscrollpos( ::handle, SB_VERT, nPos )
   hwg_Invalidaterect( ::handle, 0 )

   ::internal[1] := hwg_Setbit( ::internal[1], 1, 0 )
   IF lPaint == Nil .OR. lPaint
      hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
      hwg_Setfocus( ::handle )
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD TOP() CLASS HBrowse

   LOCAL minPos, maxPos, nPos

   hwg_Getscrollrange( ::handle, SB_VERT, @minPos, @maxPos )
   nPos := hwg_Getscrollpos( ::handle, SB_VERT )
   ::rowPos := 1
   Eval( ::bGoTop, Self )
   nPos := minPos
   hwg_Setscrollpos( ::handle, SB_VERT, nPos )
   hwg_Invalidaterect( ::handle, 0 )
   ::internal[1] := hwg_Setbit( ::internal[1], 1, 0 )
   hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD ButtonDown( lParam ) CLASS HBrowse

   LOCAL hBrw := ::handle
   LOCAL nLine := Int( hwg_Hiword( lParam )/ (::height + 1 ) + iif(::lDispHead,1 - ::nHeadRows,1 ) )
   LOCAL step := nLine - ::rowPos, res := .F. , nrec
   LOCAL minPos, maxPos, nPos
   LOCAL xm := hwg_Loword( lParam ), x1, fif

   x1  := ::x1
   fif := iif( ::freeze > 0, 1, ::nLeftCol )

   DO WHILE fif < ( ::nLeftCol + ::nColumns ) .AND. x1 + ::aColumns[ fif ]:width < xm
      x1 += ::aColumns[ fif ]:width
      fif := iif( fif == ::freeze, ::nLeftCol, fif + 1 )
   ENDDO

   IF nLine > 0 .AND. nLine <= ::rowCurrCount
      IF step != 0
         nrec := RecNo()
         Eval( ::bSkip, Self, step )
         IF !Eval( ::bEof, Self )
            ::rowPos := nLine
            IF ::bScrollPos != Nil
               Eval( ::bScrollPos, Self, step, .F. )
            ELSEIF ::nRecords > 1
               hwg_Getscrollrange( hBrw, SB_VERT, @minPos, @maxPos )
               nPos := hwg_Getscrollpos( hBrw, SB_VERT )
               nPos := Min( nPos + Int( (maxPos - minPos ) * step/(::nRecords - 1 ) ), maxPos )
               hwg_Setscrollpos( hBrw, SB_VERT, nPos )
            ENDIF
            res := .T.
         ELSE
            GO nrec
         ENDIF
      ENDIF
      IF ::lEditable

         IF ::colpos != fif - ::nLeftCol + 1 + ::freeze

            // Colpos should not go beyond last column or I get bound errors on ::Edit()
            ::colpos := Min( ::nColumns + 1, fif - ::nLeftCol + 1 + ::freeze )
            hwg_Getscrollrange( hBrw, SB_HORZ, @minPos, @maxPos )

            nPos := iif( fif == 1, ;
               minPos, ;
               iif( fif == Len( ::aColumns ), ;
               maxpos, ;
               Int( ( maxPos - minPos + 1 ) * fif / Len( ::aColumns ) ) ) )

            hwg_Setscrollpos( hBrw, SB_HORZ, nPos )
            res := .T.

         ENDIF

      ENDIF

      IF res
         hwg_Invalidaterect( hBrw, 0, ::x1, ::y1 + ( ::height + 1 ) * ::internal[2] - ::height, ::x2, ::y1 + ( ::height + 1 ) * ::internal[2] )
         hwg_Invalidaterect( hBrw, 0, ::x1, ::y1 + ( ::height + 1 ) * ::rowPos - ::height, ::x2, ::y1 + ( ::height + 1 ) * ::rowPos )
         ::internal[1] := hwg_Setbit( ::internal[1], 1, 0 )
         hwg_Postmessage( hBrw, WM_PAINT, 0, 0 )
      ENDIF

   ELSEIF ::lDispHead .AND. ;
         nLine >= - ::nHeadRows .AND. ;
         fif <= Len( ::aColumns ) .AND. ;
         ::aColumns[fif]:bHeadClick != nil

      Eval( ::aColumns[fif]:bHeadClick, Self, fif )

   ELSEIF nLine == 0
      IF hwg_isPtrEq( oCursor, ColSizeCursor )
         ::lResizing := .T.
         Hwg_SetCursor( oCursor )
         xDrag := hwg_Loword( lParam )
      ENDIF
   ENDIF

   RETURN Nil

METHOD ButtonRDown( lParam ) CLASS HBrowse

   LOCAL nLine := Int( hwg_Hiword( lParam )/ (::height + 1 ) + iif(::lDispHead,1 - ::nHeadRows,1 ) )
   LOCAL xm := hwg_Loword( lParam ), x1, fif

   IF ::bRClick == NIL
      Return Nil
   ENDIF

   x1  := ::x1
   fif := iif( ::freeze > 0, 1, ::nLeftCol )

   DO WHILE fif < ( ::nLeftCol + ::nColumns ) .AND. x1 + ::aColumns[ fif ]:width < xm
      x1 += ::aColumns[ fif ]:width
      fif := iif( fif == ::freeze, ::nLeftCol, fif + 1 )
   ENDDO

   Eval( ::bRClick, Self, nLine, fif )

   RETURN Nil

METHOD ButtonUp( lParam ) CLASS HBrowse

   LOCAL hBrw := ::handle
   LOCAL xPos := hwg_Loword( lParam ), x, x1, i

   IF ::lResizing
      x := ::x1
      i := ::nLeftCol
      DO WHILE x < xDrag
         x += ::aColumns[i]:width
         IF Abs( x - xDrag ) < 10
            x1 := x - ::aColumns[i]:width
            EXIT
         ENDIF
         i ++
      ENDDO
      IF xPos > x1
         ::aColumns[i]:width := xPos - x1
         Hwg_SetCursor( arrowCursor )
         oCursor := 0
         ::lResizing := .F.
         hwg_Invalidaterect( hBrw, 0 )
         hwg_Postmessage( hBrw, WM_PAINT, 0, 0 )
      ENDIF
   ELSEIF ::aSelected != Nil
      IF ::lCtrlPress
         IF ( i := Ascan( ::aSelected, Eval( ::bRecno,Self ) ) ) > 0
            ADel( ::aSelected, i )
            ASize( ::aSelected, Len( ::aSelected ) - 1 )
         ELSE
            AAdd( ::aSelected, Eval( ::bRecno,Self ) )
         ENDIF
      ELSE
         IF Len( ::aSelected ) > 0
            ::aSelected := {}
            ::Refresh()
         ENDIF
      ENDIF
   ENDIF
   hwg_Setfocus( ::handle )

   RETURN Nil

   //----------------------------------------------------//

METHOD ButtonDbl( lParam ) CLASS HBrowse

   LOCAL hBrw := ::handle
   LOCAL nLine := Int( hwg_Hiword( lParam )/ (::height + 1 ) + iif(::lDispHead,1 - ::nHeadRows,1 ) )

   // writelog( "ButtonDbl"+str(nLine)+ str(::rowCurrCount) )
   IF nLine > 0 .AND. nLine <= ::rowCurrCount
      ::ButtonDown( lParam )
      ::Edit()
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD MouseMove( wParam, lParam ) CLASS HBrowse

   LOCAL xPos := hwg_Loword( lParam ), yPos := hwg_Hiword( lParam )
   LOCAL x := ::x1, i := ::nLeftCol, res := .F.

   IF !::active .OR. Empty( ::aColumns ) .OR. ::x1 == Nil
      RETURN Nil
   ENDIF

   IF ::lDispSep .AND. yPos <= ::height * ::nHeadRows + 1
      wParam := hwg_PtrToUlong( wParam )
      IF wParam == 1 .AND. ::lResizing
         Hwg_SetCursor( oCursor )
         res := .T.
      ELSE
         DO WHILE x < ::x2 - 2 .AND. i <= Len( ::aColumns )
            x += ::aColumns[i++]:width
            IF Abs( x - xPos ) < 8
               IF !hwg_isPtrEq( oCursor, ColSizeCursor )
                  oCursor := ColSizeCursor
               ENDIF
               Hwg_SetCursor( oCursor )
               res := .T.
               EXIT
            ENDIF
         ENDDO
      ENDIF
      IF !res .AND. !Empty( oCursor )
         Hwg_SetCursor( arrowCursor )
         oCursor := 0
         ::lResizing := .F.
      ENDIF
   ENDIF

   RETURN Nil

   //----------------------------------------------------------------------------//

METHOD MouseWheel( nKeys, nDelta, nXPos, nYPos ) CLASS HBrowse

   IF Hwg_BitAnd( nKeys, MK_MBUTTON ) != 0
      IF nDelta > 0
         ::PageUp()
      ELSE
         ::PageDown()
      ENDIF
   ELSE
      IF nDelta > 0
         ::LineUp()
      ELSE
         ::LineDown()
      ENDIF
   ENDIF

   RETURN nil

   //----------------------------------------------------//

METHOD Edit( wParam, lParam ) CLASS HBrowse

   LOCAL fipos, lRes, x1, y1, fif, nWidth, lReadExit, rowPos
   LOCAL oModDlg, oColumn, aCoors, nChoic, bInit, oGet, type
   LOCAL oComboFont, oCombo
   LOCAL oGet1, owb1, owb2

   fipos := ::colpos + ::nLeftCol - 1 - ::freeze

   IF ::bEnter == Nil .OR. ;
         ( ValType( lRes := Eval( ::bEnter, Self, fipos ) ) == 'L' .AND. !lRes )
      oColumn := ::aColumns[fipos]
      IF ::type == BRW_DATABASE
         ::varbuf := ( ::alias ) -> ( Eval( oColumn:block,,Self,fipos ) )
      ELSE
         ::varbuf := Eval( oColumn:block, , Self, fipos )
      ENDIF
      type := iif( oColumn:type == "U" .AND. ::varbuf != Nil, ValType( ::varbuf ), oColumn:type )
      IF ::lEditable .AND. type != "O"
         IF oColumn:lEditable .AND. ( oColumn:bWhen = Nil .OR. Eval( oColumn:bWhen ) )
            IF ::lAppMode
               IF type == "D"
                  ::varbuf := CToD( "" )
               ELSEIF type == "N"
                  ::varbuf := 0
               ELSEIF type == "L"
                  ::varbuf := .F.
               ELSE
                  ::varbuf := ""
               ENDIF
            ENDIF
         ELSE
            RETURN Nil
         ENDIF
         x1  := ::x1
         fif := iif( ::freeze > 0, 1, ::nLeftCol )
         DO WHILE fif < fipos
            x1 += ::aColumns[fif]:width
            fif := iif( fif = ::freeze, ::nLeftCol, fif + 1 )
         ENDDO
         nWidth := Min( ::aColumns[fif]:width, ::x2 - x1 - 1 )
         rowPos := ::rowPos - 1
         IF ::lAppMode .AND. ::nRecords != 0
            rowPos ++
         ENDIF
         y1 := ::y1 + ( ::height + 1 ) * rowPos

         // aCoors := hwg_Getwindowrect( ::handle )
         // x1 += aCoors[1]
         // y1 += aCoors[2]

         aCoors := hwg_Clienttoscreen( ::handle, x1, y1 )
         x1 := aCoors[1]
         y1 := aCoors[2]

         lReadExit := Set( _SET_EXIT, .T. )
         bInit := iif( wParam == Nil, { |o|hwg_Movewindow( o:handle,x1,y1,nWidth,o:nHeight + 1 ) }, ;
            { |o|hwg_Movewindow( o:handle, x1, y1, nWidth, o:nHeight + 1 ), hwg_Postmessage( o:aControls[1]:handle, WM_KEYDOWN, wParam, lParam ) } )

         IF type <> "M"
            INIT DIALOG oModDlg;
               STYLE WS_POPUP + 1 + iif( oColumn:aList == Nil, WS_BORDER, 0 ) ;
               AT x1, y1 - iif( oColumn:aList == Nil, 1, 0 ) ;
               SIZE nWidth, ::height + iif( oColumn:aList == Nil, 1, 0 ) ;
               ON INIT bInit
         ELSE
            INIT DIALOG oModDlg title "memo edit" AT 0, 0 SIZE 400, 300 ON INIT { |o|o:center() }
         ENDIF

         IF oColumn:aList != Nil
            oModDlg:brush := - 1
            oModDlg:nHeight := ::height * 5

            IF ValType( ::varbuf ) == 'N'
               nChoic := ::varbuf
            ELSE
               ::varbuf := AllTrim( ::varbuf )
               nChoic := Ascan( oColumn:aList, ::varbuf )
            ENDIF

            /* 21/09/2005 - <maurilio.longo@libero.it>
                            The combobox needs to use a font smaller than the one used
                            by the browser or it will be taller than the browse row that
                            has to contain it.
            */
            oComboFont := iif( ValType( ::oFont ) == "U", ;
               HFont():Add( "MS Sans Serif", 0, - 8 ), ;
               HFont():Add( ::oFont:name, ::oFont:width, ::oFont:height + 2 ) )

            @ 0, 0 GET COMBOBOX oCombo VAR nChoic ;
               ITEMS oColumn:aList            ;
               SIZE nWidth, ::height * 5      ;
               FONT oComboFont

            IF oColumn:bValid != NIL
               oCombo:bValid := oColumn:bValid
            ENDIF

         ELSE
            IF type <> "M"
               @ 0, 0 GET oGet VAR ::varbuf      ;
                  SIZE nWidth, ::height + 1      ;
                  NOBORDER                       ;
                  STYLE ES_AUTOHSCROLL           ;
                  FONT ::oFont                   ;
                  PICTURE oColumn:picture        ;
                  VALID oColumn:bValid
            ELSE
               oGet1 := ::varbuf
               @ 10, 10 GET oGet1 SIZE oModDlg:nWidth - 20, 240 FONT ::oFont Style WS_VSCROLL + WS_HSCROLL + ES_MULTILINE VALID oColumn:bValid
               @ 010, 252 ownerbutton owb2 TEXT "Save" size 80, 24 ON Click { ||::varbuf := oGet1, omoddlg:close(), oModDlg:lResult := .T. }
               @ 100, 252 ownerbutton owb1 TEXT "Close" size 80, 24 ON CLICK { ||oModDlg:close() }
            ENDIF
         ENDIF

         ACTIVATE DIALOG oModDlg

         IF oColumn:aList != Nil
            oComboFont:Release()
         ENDIF

         IF oModDlg:lResult
            IF oColumn:aList != Nil
               IF ValType( ::varbuf ) == 'N'
                  ::varbuf := nChoic
               ELSE
                  ::varbuf := oColumn:aList[nChoic]
               ENDIF
            ENDIF
            IF ::lAppMode
               ::lAppMode := .F.
               IF ::type == BRW_DATABASE
                  ( ::alias ) -> ( dbAppend() )
                  ( ::alias ) -> ( Eval( oColumn:block,::varbuf,Self,fipos ) )
                  UNLOCK
               ELSE
                  IF ValType( ::aArray[1] ) == "A"
                     AAdd( ::aArray, Array( Len(::aArray[1] ) ) )
                     FOR fif := 2 TO Len( ( ::aArray[1] ) )
                        ::aArray[Len(::aArray),fif] := ;
                           iif( ::aColumns[fif]:type == "D", CToD( Space(8 ) ), ;
                           iif( ::aColumns[fif]:type == "N", 0, "" ) )
                     NEXT
                  ELSE
                     AAdd( ::aArray, Nil )
                  ENDIF
                  ::nCurrent := Len( ::aArray )
                  Eval( oColumn:block, ::varbuf, Self, fipos )
               ENDIF
               IF ::nRecords > 0
                  ::rowPos ++
               ENDIF
               ::lAppended := .T.
               ::Refresh()
            ELSE
               IF ::type == BRW_DATABASE
                  IF ( ::alias ) -> ( RLock() )
                     ( ::alias ) -> ( Eval( oColumn:block,::varbuf,Self,fipos ) )
                  ELSE
                     hwg_Msgstop( "Can't lock the record!" )
                  ENDIF
               ELSE
                  Eval( oColumn:block, ::varbuf, Self, fipos )
               ENDIF

               ::lUpdated := .T.
               hwg_Invalidaterect( ::handle, 0, ::x1, ::y1 + ( ::height + 1 ) * ( ::rowPos - 2 ), ::x2, ::y1 + ( ::height + 1 ) * ::rowPos )
               ::RefreshLine()
            ENDIF

            /* Execute block after changes are made */
            IF ::bUpdate != nil
               Eval( ::bUpdate,  Self, fipos )
            END

         ELSEIF ::lAppMode
            ::lAppMode := .F.
            hwg_Invalidaterect( ::handle, 0, ::x1, ::y1 + ( ::height + 1 ) * ::rowPos, ::x2, ::y1 + ( ::height + 1 ) * ( ::rowPos + 2 ) )
            ::RefreshLine()
         ENDIF
         hwg_Setfocus( ::handle )
         SET( _SET_EXIT, lReadExit )

      ENDIF
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

METHOD RefreshLine() CLASS HBrowse

   ::internal[1] := 0
   hwg_Invalidaterect( ::handle, 0, ::x1, ::y1 + ( ::height + 1 ) * ::rowPos - ::height, ::x2, ::y1 + ( ::height + 1 ) * ::rowPos )
   hwg_Sendmessage( ::handle, WM_PAINT, 0, 0 )

   RETURN Nil

   //----------------------------------------------------//

METHOD Refresh( lFull ) CLASS HBrowse

   IF lFull == Nil .OR. lFull
      IF ::lFilter
         ::nLastRecordFilter := 0
         ::nFirstRecordFilter := 0
         FltGoTop( Self )
      ENDIF
      ::internal[1] := 15
      hwg_Redrawwindow( ::handle, RDW_ERASE + RDW_INVALIDATE + RDW_INTERNALPAINT + RDW_UPDATENOW )
   ELSE
      hwg_Invalidaterect( ::handle, 0 )
      ::internal[1] := hwg_Setbit( ::internal[1], 1, 0 )
      hwg_Postmessage( ::handle, WM_PAINT, 0, 0 )
   ENDIF

   RETURN Nil

   //----------------------------------------------------//

STATIC FUNCTION FldStr( oBrw, numf )

   LOCAL cRes, vartmp, type, pict

   IF numf <= Len( oBrw:aColumns )

      pict := oBrw:aColumns[numf]:picture

      IF pict != nil
         IF oBrw:type == BRW_DATABASE
            IF oBrw:aRelation
               cRes := ( oBrw:aColAlias[numf] ) -> ( Transform( Eval( oBrw:aColumns[numf]:block,,oBrw,numf ), pict ) )
            ELSE
               cRes := ( oBrw:alias ) -> ( Transform( Eval( oBrw:aColumns[numf]:block,,oBrw,numf ), pict ) )
            ENDIF
         ELSE
            cRes := Transform( Eval( oBrw:aColumns[numf]:block,,oBrw,numf ), pict )
         ENDIF
      ELSE
         IF oBrw:type == BRW_DATABASE
            IF oBrw:aRelation
               vartmp := ( oBrw:aColAlias[numf] ) -> ( Eval( oBrw:aColumns[numf]:block,,oBrw,numf ) )
            ELSE
               vartmp := ( oBrw:alias ) -> ( Eval( oBrw:aColumns[numf]:block,,oBrw,numf ) )
            ENDIF
         ELSE
            vartmp := Eval( oBrw:aColumns[numf]:block, , oBrw, numf )
         ENDIF

         type := ( oBrw:aColumns[numf] ):type
         IF type == "U" .AND. vartmp != Nil
            type := ValType( vartmp )
         ENDIF
         IF type == "C"
            //cRes := Padr( vartmp, oBrw:aColumns[numf]:length )
            cRes := vartmp
         ELSEIF type == "N"
            cRes := PadL( Str( vartmp, oBrw:aColumns[numf]:length, ;
               oBrw:aColumns[numf]:dec ), oBrw:aColumns[numf]:length )
         ELSEIF type == "D"
            cRes := PadR( Dtoc( vartmp ), oBrw:aColumns[numf]:length )

         ELSEIF type == "L"
            cRes := PadR( iif( vartmp, "T", "F" ), oBrw:aColumns[numf]:length )

         ELSEIF type == "M"
            cRes := iif( Empty( vartmp ), "<memo>", "<MEMO>" )

         ELSEIF type == "O"
            cRes := "<" + vartmp:Classname() + ">"

         ELSEIF type == "A"
            cRes := "<Array>"

         ELSE
            cRes := Space( oBrw:aColumns[numf]:length )
         ENDIF
      ENDIF
   ENDIF

   RETURN cRes

   //----------------------------------------------------//

STATIC FUNCTION FLDCOUNT( oBrw, xstrt, xend, fld1 )

   LOCAL klf := 0, i := iif( oBrw:freeze > 0, 1, fld1 )

   DO WHILE .T.
      // xstrt += ( MAX( oBrw:aColumns[i]:length, LEN( oBrw:aColumns[i]:heading ) ) - 1 ) * oBrw:width
      xstrt += oBrw:aColumns[i]:width
      IF xstrt > xend
         EXIT
      ENDIF
      klf ++
      i   := iif( i = oBrw:freeze, fld1, i + 1 )
      // xstrt += 2 * oBrw:width
      IF i > Len( oBrw:aColumns )
         EXIT
      ENDIF
   ENDDO

   RETURN iif( klf = 0, 1, klf )

   //----------------------------------------------------//

FUNCTION hwg_CREATEARLIST( oBrw, arr )

   LOCAL i

   oBrw:type  := BRW_ARRAY
   oBrw:aArray := arr
   IF Len( oBrw:aColumns ) == 0
      // oBrw:aColumns := {}
      IF ValType( arr[1] ) == "A"
         FOR i := 1 TO Len( arr[1] )
            oBrw:AddColumn( { ,hwg_ColumnArBlock() } )
         NEXT
      ELSE
         oBrw:AddColumn( { ,{ |value,o| o:aArray[ o:nCurrent ] } } )
      ENDIF
   ENDIF
   Eval( oBrw:bGoTop, oBrw )
   oBrw:Refresh()

   RETURN Nil

   //----------------------------------------------------//

PROCEDURE ARSKIP( oBrw, nSkip )

   LOCAL nCurrent1

   IF oBrw:nRecords != 0
      nCurrent1   := oBrw:nCurrent
      oBrw:nCurrent += nSkip + iif( nCurrent1 = 0, 1, 0 )
      IF oBrw:nCurrent < 1
         oBrw:nCurrent := 0
      ELSEIF oBrw:nCurrent > oBrw:nRecords
         oBrw:nCurrent := oBrw:nRecords + 1
      ENDIF
   ENDIF

   RETURN

   //----------------------------------------------------//

FUNCTION hwg_CreateList( oBrw, lEditable )

   LOCAL i
   LOCAL nArea := Select()
   LOCAL kolf := FCount()

   oBrw:alias   := Alias()

   oBrw:aColumns := {}
   FOR i := 1 TO kolf
      oBrw:AddColumn( { FieldName(i ),         ;
         FieldWBlock( FieldName( i ), nArea ), ;
         dbFieldInfo( DBS_TYPE, i ),         ;
         iif( dbFieldInfo( DBS_TYPE,i ) == "D" .AND. __SetCentury(), 10, dbFieldInfo( DBS_LEN,i ) ), ;
         dbFieldInfo( DBS_DEC, i ),          ;
         lEditable } )
   NEXT

   oBrw:Refresh()

   RETURN Nil

FUNCTION hwg_VScrollPos( oBrw, nType, lEof, nPos )

   LOCAL minPos, maxPos, oldRecno, newRecno

   hwg_Getscrollrange( oBrw:handle, SB_VERT, @minPos, @maxPos )
   IF nPos == Nil
      IF nType > 0 .AND. lEof
         Eval( oBrw:bSkip, oBrw, - 1 )
      ENDIF
      nPos := iif( oBrw:nRecords > 1, Round( ( (maxPos - minPos )/(oBrw:nRecords - 1 ) ) * ;
         ( Eval( oBrw:bRecnoLog,oBrw ) - 1 ), 0 ), minPos )
      hwg_Setscrollpos( oBrw:handle, SB_VERT, nPos )
   ELSE
      oldRecno := Eval( oBrw:bRecnoLog, oBrw )
      newRecno := Round( ( oBrw:nRecords - 1 ) * nPos/ (maxPos - minPos ) + 1,0 )
      IF newRecno <= 0
         newRecno := 1
      ELSEIF newRecno > oBrw:nRecords
         newRecno := oBrw:nRecords
      ENDIF
      IF nType == SB_THUMBPOSITION
         hwg_Setscrollpos( oBrw:handle, SB_VERT, nPos )
      ENDIF
      IF newRecno != oldRecno
         Eval( oBrw:bSkip, oBrw, newRecno - oldRecno )
         IF oBrw:rowCount - oBrw:rowPos > oBrw:nRecords - newRecno
            oBrw:rowPos := oBrw:rowCount - ( oBrw:nRecords - newRecno )
         ENDIF
         IF oBrw:rowPos > newRecno
            oBrw:rowPos := newRecno
         ENDIF
         oBrw:Refresh( .F. )
      ENDIF
   ENDIF

   RETURN Nil

FUNCTION hwg_HScrollPos( oBrw, nType, lEof, nPos )

   LOCAL minPos, maxPos, i, nSize := 0, nColPixel
   LOCAL nBWidth := oBrw:nWidth // :width is _not_ browse width

   hwg_Getscrollrange( oBrw:handle, SB_HORZ, @minPos, @maxPos )

   IF nType == SB_THUMBPOSITION

      nColPixel := Int( ( nPos * nBWidth ) / ( ( maxPos - minPos ) + 1 ) )
      i := oBrw:nLeftCol - 1

      WHILE nColPixel > nSize .AND. i < Len( oBrw:aColumns )
         nSize += oBrw:aColumns[ ++i ]:width
      ENDDO

      // colpos is relative to leftmost column, as it seems, so I subtract leftmost column number
      oBrw:colpos := Max( i, oBrw:nLeftCol ) - oBrw:nLeftCol + 1
   ENDIF

   hwg_Setscrollpos( oBrw:handle, SB_HORZ, nPos )

   RETURN Nil

   //----------------------------------------------------//
   // Agregado x WHT. 27.07.02
   // Locus metodus.

METHOD ShowSizes() CLASS HBrowse

   LOCAL cText := ""

   AEval( ::aColumns, ;
      { | v, e | cText += ::aColumns[e]:heading + ": " + Str( Round( ::aColumns[e]:width/8,0 ) - 2  ) + Chr( 10 ) + Chr( 13 ) } )
   hwg_Msginfo( cText )

   RETURN nil

FUNCTION hwg_ColumnArBlock()

   RETURN { |value, o, n| iif( value == Nil, o:aArray[o:nCurrent,n], o:aArray[o:nCurrent,n] := value ) }

STATIC FUNCTION HdrToken( cStr, nMaxLen, nCount )

   LOCAL nL, nPos := 0

   nMaxLen := nCount := 0
   cStr += ';'
   DO WHILE ( nL := Len( hb_tokenPtr( @cStr, @nPos, ";" ) ) ) != 0
      nMaxLen := Max( nMaxLen, nL )
      nCount ++
   ENDDO

   RETURN nil

   // By Luiz Henrique dos Santos (luizhsantos@gmail.com)

STATIC FUNCTION FltSkip( oBrw, nLines, lDesc )

   LOCAL n, r

   IF nLines == NIL
      nLines := 1
   ENDIF
   IF lDesc == NIL
      lDesc := .F.
   ENDIF
   IF nLines > 0
      FOR n := 1 TO nLines
         SKIP IF( lDesc, - 1, + 1 )
         WHILE ! Eof() .AND. Eval( oBrw:bWhile ) .AND. ! Eval( oBrw:bFor )
            SKIP IF( lDesc, - 1, + 1 )
         ENDDO
      NEXT
   ELSEIF nLines < 0
      FOR n := 1 TO ( nLines * ( - 1 ) )
         IF Eof()
            IF lDesc
               FltGoTop( oBrw )
            ELSE
               FltGoBottom( oBrw )
            ENDIF
         ELSE
            SKIP IF( lDesc, + 1, - 1 )
         ENDIF
         WHILE ! Bof() .AND. Eval( oBrw:bWhile ) .AND. ! Eval( oBrw:bFor )
            SKIP IF( lDesc, + 1, - 1 )
         ENDDO
      NEXT
   ENDIF

   RETURN NIL

STATIC FUNCTION FltGoTop( oBrw )

   IF oBrw:nFirstRecordFilter == 0
      Eval( oBrw:bFirst )
      IF ! Eof()
         WHILE ! Eof() .AND. ! ( Eval( oBrw:bWhile ) .AND. Eval( oBrw:bFor ) )
            dbSkip()
         ENDDO
         oBrw:nFirstRecordFilter := FltRecNo( oBrw )
      ELSE
         oBrw:nFirstRecordFilter := 0
      ENDIF
   ELSE
      FltGoTo( oBrw, oBrw:nFirstRecordFilter )
   ENDIF

   RETURN NIL

STATIC FUNCTION FltGoBottom( oBrw )

   IF oBrw:nLastRecordFilter == 0
      Eval( oBrw:bLast )
      IF ! Eval( oBrw:bWhile ) .OR. ! Eval( oBrw:bFor )
         WHILE ! Bof() .AND. ! Eval( oBrw:bWhile )
            dbSkip( - 1 )
         ENDDO
         WHILE ! Bof() .AND. Eval( oBrw:bWhile ) .AND. ! Eval( oBrw:bFor )
            dbSkip( - 1 )
         ENDDO
      ENDIF
      oBrw:nLastRecordFilter := FltRecNo( oBrw )
   ELSE
      FltGoTo( oBrw, oBrw:nLastRecordFilter )
   ENDIF

   RETURN NIL

STATIC FUNCTION FltBOF( oBrw )

   LOCAL lRet := .F. , cKey := "", nRecord := 0
   LOCAL xValue, xFirstValue

   IF Bof()
      lRet := .T.
   ELSE
      cKey  := IndexKey()
      nRecord := FltRecNo( oBrw )

      xValue := OrdKeyNo() //&(cKey)

      FltGoTop( oBrw )
      xFirstValue := OrdKeyNo()//&(cKey)

      IF xValue < xFirstValue
         lRet := .T.
         FltGoTop( oBrw )
      ELSE
         FltGoTo( oBrw, nRecord )
      ENDIF
   ENDIF

   RETURN lRet

STATIC FUNCTION FltEOF( oBrw )

   LOCAL lRet := .F. , cKey := "", nRecord := 0
   LOCAL xValue, xLastValue

   IF Eof()
      lRet := .T.
   ELSE
      cKey := IndexKey()
      nRecord := FltRecNo( oBrw )

      xValue := OrdKeyNo()

      FltGoBottom( oBrw )
      xLastValue := OrdKeyNo()

      IF xValue > xLastValue
         lRet := .T.
         FltGoBottom( oBrw )
         dbSkip()
      ELSE
         FltGoTo( oBrw, nRecord )
      ENDIF
   ENDIF

   RETURN lRet

STATIC FUNCTION FltRecCount( oBrw )

   LOCAL nRecord := 0, nCount := 0

   nRecord := FltRecNo( oBrw )
   FltGoTop( oBrw )
   WHILE ! Eof() .AND. Eval( oBrw:bWhile )
      IF Eval( oBrw:bFor )
         nCount ++
      ENDIF
      dbSkip()
   ENDDO
   FltGoTo( oBrw, nRecord )

   RETURN nCount

STATIC FUNCTION FltGoTo( oBrw, nRecord )

   RETURN dbGoto( nRecord )

STATIC FUNCTION FltRecNo( oBrw )

   RETURN RecNo()

   //End Implementation by Luiz


