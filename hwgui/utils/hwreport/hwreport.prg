/*
 * $Id: hwreport.prg 2216 2014-01-20 06:25:46Z alkresin $
 *
 * Repbuild - Visual Report Builder
 * Main file
 *
 * Copyright 2001 Alexander S.Kresin <alex@belacy.belgorod.su>
 * www - http://kresin.belgorod.su
*/

#include "windows.ch"
#include "guilib.ch"
#include "repbuild.h"
#include "repmain.h"

#define SB_VERT         1
#define IDCW_STATUS  2001

Static nAddItem := 0, nMarkerType := 0
Static crossCursor, vertCursor, horzCursor
Static itemPressed := 0, mPos := { 0,0 }
Static itemBorder := 0, itemSized := 0, resizeDirection := 0
Static aInitialSize := { { 50,20 }, { 60,4 }, { 4,60 }, { 60,40 }, { 40,40 }, { 16,10 } }
Static aMarkers := { "PH","SL","EL","PF","EPF","DF" }
Static oPenDivider, oPenLine

Memvar mypath
Memvar aPaintRep
Memvar oPenBorder, oFontSmall, oFontStandard, lastFont
Memvar aItemTypes

Function Main()
Local oMainWindow, aPanel, oIcon := HIcon():AddResource("ICON_1")
Public mypath := "\" + CURDIR() + IIF( EMPTY( CURDIR() ), "", "\" )
Public aPaintRep := Nil
Public oPenBorder, oFontSmall, oFontStandard, lastFont := Nil
Public aItemTypes := { "TEXT","HLINE","VLINE","BOX","BITMAP","MARKER" }

   SET DECIMALS TO 4
   crossCursor := hwg_Loadcursor( IDC_CROSS )
   horzCursor := hwg_Loadcursor( IDC_SIZEWE )
   vertCursor := hwg_Loadcursor( IDC_SIZENS )
   oPenBorder := HPen():Add( PS_SOLID,1,hwg_VColor("800080") )
   oPenLine   := HPen():Add( PS_SOLID,1,hwg_VColor("000000") )
   oPenDivider := HPen():Add( PS_DOT,1,hwg_VColor("C0C0C0") )
   oFontSmall := HFont():Add( "Small fonts",0,-8 )
   oFontStandard := HFont():Add( "Arial",0,-13,400,204 )

   INIT WINDOW oMainWindow MAIN TITLE "Visual Report Builder"  ;
       ICON oIcon SYSCOLOR COLOR_3DSHADOW                      ;
       ON PAINT {|o|PaintMain(o)} ON EXIT {||CloseReport()}    ;
       ON OTHER MESSAGES {|o,m,wp,lp|MessagesProc(o,m,wp,lp)}

   ADD STATUS TO oMainWindow ID IDCW_STATUS PARTS 240,180,0

   MENU OF oMainWindow
      MENU TITLE "&File"
         MENUITEM "&New" ID IDM_NEW ACTION NewReport(oMainWindow)
         MENUITEM "&Open" ID IDM_OPEN ACTION FileDlg(.T.)
         MENUITEM "&Close" ID IDM_CLOSE ACTION CloseReport()
         SEPARATOR
         MENUITEM "&Save" ID IDM_SAVE ACTION SaveReport()
         MENUITEM "Save &as..." ID IDM_SAVEAS ACTION FileDlg(.F.)
         SEPARATOR
         MENUITEM "&Print static" ID IDM_PRINT ACTION PrintRpt()
         MENUITEM "&Print full" ID IDM_PREVIEW ACTION (hwg_ClonePaintRep(aPaintRep),hwg_PrintReport(,,.T.))
         SEPARATOR
         MENUITEM "&Exit" ID IDM_EXIT ACTION hwg_EndWindow()
      ENDMENU
      MENU TITLE "&Items"
         MENUITEM "&Text" ID IDM_ITEMTEXT ACTION nAddItem:=TYPE_TEXT
         MENUITEM "&Horizontal Line" ID IDM_ITEMHLINE ACTION nAddItem:=TYPE_HLINE
         MENUITEM "&Vertical Line" ID IDM_ITEMVLINE ACTION nAddItem:=TYPE_VLINE
         MENUITEM "&Box" ID IDM_ITEMBOX ACTION nAddItem:=TYPE_BOX
         MENUITEM "B&itmap" ID IDM_ITEMBITM ACTION nAddItem:=TYPE_BITMAP
         SEPARATOR
         MENU TITLE "&Markers"
            MENUITEM "&Page Header" ID IDM_ITEMPH ACTION (nAddItem:=TYPE_MARKER,nMarkerType:=MARKER_PH)
            MENUITEM "&Start line" ID IDM_ITEMSL ACTION (nAddItem:=TYPE_MARKER,nMarkerType:=MARKER_SL)
            MENUITEM "&End line" ID IDM_ITEMEL ACTION (nAddItem:=TYPE_MARKER,nMarkerType:=MARKER_EL)
            MENUITEM "Page &Footer" ID IDM_ITEMPF ACTION (nAddItem:=TYPE_MARKER,nMarkerType:=MARKER_PF)
            MENUITEM "E&nd of Page Footer" ID IDM_ITEMEPF ACTION (nAddItem:=TYPE_MARKER,nMarkerType:=MARKER_EPF)
            MENUITEM "&Document Footer" ID IDM_ITEMDF ACTION (nAddItem:=TYPE_MARKER,nMarkerType:=MARKER_DF)
         ENDMENU
         SEPARATOR
         MENUITEM "&Delete item" ID IDM_ITEMDEL ACTION DeleteItem()
      ENDMENU
      MENU TITLE "&Options"
         MENUITEM "&Form options" ID IDM_FOPT ACTION FormOptions()
         MENUITEM "&Preview" ID IDM_VIEW1 ACTION (hwg_Showscrollbar(oMainWindow:handle,SB_VERT,hwg_Ischeckedmenuitem(,IDM_VIEW1)),hwg_Checkmenuitem(,IDM_VIEW1,!hwg_Ischeckedmenuitem(,IDM_VIEW1)),Iif(hwg_Ischeckedmenuitem(,IDM_VIEW1),DeselectAll(),),hwg_Redrawwindow(Hwindow():GetMain():handle,RDW_ERASE+RDW_INVALIDATE))
         // MENUITEM "&Preview" ID IDM_VIEW1 ACTION (hwg_Showscrollbar(oMainWindow:handle,SB_VERT,hwg_Ischeckedmenuitem(,IDM_VIEW1)),hwg_Checkmenuitem(,IDM_VIEW1,!hwg_Ischeckedmenuitem(,IDM_VIEW1)),Iif(hwg_Ischeckedmenuitem(,IDM_VIEW1),DeselectAll(),.F.),hwg_Redrawwindow(Hwindow():GetMain():handle,RDW_ERASE+RDW_INVALIDATE))
         MENUITEM "&Mouse limit" ID IDM_MOUSE2 ACTION (hwg_Checkmenuitem(,IDM_MOUSE2,!hwg_Ischeckedmenuitem(,IDM_MOUSE2)))
      ENDMENU
      MENUITEM "&About" ID IDM_ABOUT ACTION About()
   ENDMENU

   hwg_Enablemenuitem( ,IDM_CLOSE, .F., .T. )
   hwg_Enablemenuitem( ,IDM_SAVE, .F., .T. )
   hwg_Enablemenuitem( ,IDM_SAVEAS, .F., .T. )
   hwg_Enablemenuitem( ,IDM_PRINT, .F., .T. )
   hwg_Enablemenuitem( ,IDM_PREVIEW, .F., .T. )
   hwg_Enablemenuitem( ,IDM_FOPT, .F., .T. )
   hwg_Enablemenuitem( ,1, .F., .F. )
   hwg_Checkmenuitem( ,IDM_MOUSE2, .t. )

   oMainWindow:Activate()

Return Nil

Function About
Local aModDlg, oFont

   INIT DIALOG aModDlg FROM RESOURCE "ABOUTDLG"
   PREPARE FONT oFont NAME "MS Sans Serif" WIDTH 0 HEIGHT -13 ITALIC UNDERLINE

   REDEFINE SAY "HWREPORT" OF aModDlg ID 101 COLOR hwg_VColor("0000FF")
   REDEFINE OWNERBUTTON OF aModDlg ID IDC_OWNB1 ON CLICK {|| hwg_EndDialog( hwg_GetModalHandle() )} ;
       FLAT TEXT "Close" COLOR hwg_VColor("0000FF") FONT oFont

   aModDlg:Activate()
Return Nil

Static Function NewReport( oMainWindow )
Local oDlg

   INIT DIALOG oDlg FROM RESOURCE "DLG_NEWREP" ON INIT {||hwg_Checkradiobutton( oDlg:handle,IDC_RADIOBUTTON1,IDC_RADIOBUTTON2,IDC_RADIOBUTTON1)}
   DIALOG ACTIONS OF oDlg ;
        ON 0,IDOK  ACTION {|| EndNewrep(oMainWindow,oDlg)}

   oDlg:Activate()

Return Nil

Static Function EndNewrep( oMainWindow,oDlg )

   aPaintRep := { 0,0,0,0,0,{},"","",.F.,0,Nil }
   IF hwg_Isdlgbuttonchecked( oDlg:handle,IDC_RADIOBUTTON1 )
      aPaintRep[FORM_WIDTH] := 210 ; aPaintRep[FORM_HEIGHT] := 297
   ELSE
      aPaintRep[FORM_WIDTH] := 297 ; aPaintRep[FORM_HEIGHT] := 210
   ENDIF

   aPaintRep[FORM_Y] := 0
   hwg_Enablemenuitem( ,1, .T., .F. )
   hwg_WriteStatus( oMainWindow,2,Ltrim(Str(aPaintRep[FORM_WIDTH],4))+"x"+ ;
                 Ltrim(Str(aPaintRep[FORM_HEIGHT],4))+"  Items: "+Ltrim(Str(Len(aPaintRep[FORM_ITEMS]))) )
   hwg_Redrawwindow( oMainWindow:handle, RDW_ERASE + RDW_INVALIDATE )

   hwg_EndDialog()
Return Nil

Static Function PaintMain( oWnd )
Local pps, hDC, hWnd := oWnd:handle
Local x1 := LEFT_INDENT, y1 := TOP_INDENT, x2, y2, oldBkColor, aMetr, nWidth, nHeight, lPreview := .F.
Local n1cm, xt, yt
Local i, j, aItem
Local aCoors
Local step, kolsteps, nsteps

   IF aPaintRep == Nil
      Return -1
   ENDIF

   pps := hwg_Definepaintstru()
   hDC := hwg_Beginpaint( hWnd, pps )
   aCoors := hwg_Getclientrect( hWnd )

   IF aPaintRep[FORM_XKOEFCONST] == 0
      aMetr := hwg_GetDeviceArea( hDC )
      aPaintRep[FORM_XKOEFCONST] := ( aMetr[1]-XINDENT )/aPaintRep[FORM_WIDTH]
   ENDIF

   IF hwg_Ischeckedmenuitem( ,IDM_VIEW1 )
      lPreview := .T.
      aPaintRep[FORM_Y] := 0
      IF aPaintRep[FORM_WIDTH] > aPaintRep[FORM_HEIGHT]
         nWidth := aCoors[3] - aCoors[1] - XINDENT
         nHeight := Round( nWidth * aPaintRep[FORM_HEIGHT] / aPaintRep[FORM_WIDTH], 0 )
         IF nHeight > aCoors[4] - aCoors[2] - YINDENT
            nHeight := aCoors[4] - aCoors[2] - YINDENT
            nWidth := Round( nHeight * aPaintRep[FORM_WIDTH] / aPaintRep[FORM_HEIGHT], 0 )
         ENDIF
      ELSE
         nHeight := aCoors[4] - aCoors[2] - YINDENT
         nWidth := Round( nHeight * aPaintRep[FORM_WIDTH] / aPaintRep[FORM_HEIGHT], 0 )
         IF nWidth > aCoors[3] - aCoors[1] - XINDENT
            nWidth := aCoors[3] - aCoors[1] - XINDENT
            nHeight := Round( nWidth * aPaintRep[FORM_HEIGHT] / aPaintRep[FORM_WIDTH], 0 )
         ENDIF
      ENDIF
      aPaintRep[FORM_XKOEF] := nWidth/aPaintRep[FORM_WIDTH]
   ELSE
      aPaintRep[FORM_XKOEF] := aPaintRep[FORM_XKOEFCONST]
   ENDIF

   x2 := x1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0)-1
   y2 := y1+Round(aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEF],0)-aPaintRep[FORM_Y]-1
   n1cm := Round(aPaintRep[FORM_XKOEF]*10,0)
   step := n1cm*2
   nsteps := Round(aPaintRep[FORM_Y]/step,0)

   hwg_Fillrect( hDC, 0, 0, aCoors[3], TOP_INDENT-5, COLOR_HIGHLIGHTTEXT+1 )
   hwg_Fillrect( hDC, 0, 0, LEFT_INDENT-12, aCoors[4], COLOR_3DLIGHT+1 )
   i := 0
   hwg_Selectobject( hDC,oPenLine:handle )
   hwg_Selectobject( hDC,Iif(lPreview,oFontSmall:handle,oFontStandard:handle) )
   oldBkColor := hwg_Setbkcolor( hDC,hwg_Getsyscolor(COLOR_3DLIGHT) )
   DO WHILE i <= aPaintRep[FORM_WIDTH]/10 .AND. i*n1cm < (aCoors[3]-aCoors[1]-LEFT_INDENT)
      xt := x1+i*n1cm
      hwg_Drawline( hDC,xt+Round(n1cm/4,0),0,xt+Round(n1cm/4,0),4 )
      hwg_Drawline( hDC,xt+Round(n1cm/2,0),0,xt+Round(n1cm/2,0),8 )
      hwg_Drawline( hDC,xt+Round(n1cm*3/4,0),0,xt+Round(n1cm*3/4,0),4 )
      hwg_Drawline( hDC,xt,0,xt,12 )
      IF i > 0 .AND. i < aPaintRep[FORM_WIDTH]/10
         hwg_Drawtext( hDC,Ltrim(Str(i,2)),xt-15,12,xt+15,TOP_INDENT-5,DT_CENTER )
      ENDIF
      i++
   ENDDO
   i := 0
   DO WHILE i <= aPaintRep[FORM_HEIGHT]/10 .AND. i*n1cm < (aCoors[4]-aCoors[2]-TOP_INDENT)
      yt := y1+i*n1cm
      hwg_Drawline( hDC,0,yt+Round(n1cm/4,0),4,yt+Round(n1cm/4,0) )
      hwg_Drawline( hDC,0,yt+Round(n1cm/2,0),8,yt+Round(n1cm/2,0) )
      hwg_Drawline( hDC,0,yt+Round(n1cm*3/4,0),4,yt+Round(n1cm*3/4,0) )
      hwg_Drawline( hDC,0,yt,12,yt )
      IF i > 0 .AND. i < aPaintRep[FORM_HEIGHT]/10
         hwg_Drawtext( hDC,Ltrim(Str(i+nsteps*2,2)),12,yt-10,LEFT_INDENT-12,yt+10,DT_CENTER )
      ENDIF
      i++
   ENDDO
   hwg_Fillrect( hDC, LEFT_INDENT-12, y1, x1, y2, COLOR_3DSHADOW+1 )
   hwg_Fillrect( hDC, x1, y1, x2, y2, COLOR_WINDOW+1 )
   hwg_Setbkcolor( hDC,hwg_Getsyscolor(COLOR_WINDOW) )
   FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
      IF aPaintRep[FORM_ITEMS,i,ITEM_TYPE] != TYPE_BITMAP
         PaintItem( hDC, aPaintRep[FORM_ITEMS,i], aCoors, lPreview )
      ENDIF
   NEXT
   FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
      IF aPaintRep[FORM_ITEMS,i,ITEM_TYPE] == TYPE_BITMAP
         PaintItem( hDC, aPaintRep[FORM_ITEMS,i], aCoors, lPreview )
      ENDIF
   NEXT
   hwg_Setbkcolor( hDC,oldBkColor )

   kolsteps := Round( ( Round(aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEF],0)- ;
      (aCoors[4]-aCoors[2]-TOP_INDENT) ) / step, 0 ) + 1
   IF lPreview
      hwg_Setscrollinfo( hWnd, SB_VERT, 1 )
   ELSE
      hwg_Setscrollinfo( hWnd, SB_VERT, 1, nSteps+1, 1, kolsteps+1 )
   ENDIF

   hwg_Endpaint( hWnd, pps )
Return 0

Static Function PaintItem( hDC, aItem, aCoors, lPreview )
Local x1 := LEFT_INDENT + aItem[ITEM_X1], y1 := TOP_INDENT + aItem[ITEM_Y1] - aPaintRep[FORM_Y]
Local x2 := x1+aItem[ITEM_WIDTH]-1, y2 := y1+aItem[ITEM_HEIGHT]-1

   IF lPreview
      x1 := LEFT_INDENT + aItem[ITEM_X1]*aPaintRep[FORM_XKOEF]/aPaintRep[FORM_XKOEFCONST]
      x2 := LEFT_INDENT + (aItem[ITEM_X1]+aItem[ITEM_WIDTH]-1)*aPaintRep[FORM_XKOEF]/aPaintRep[FORM_XKOEFCONST]
      y1 := TOP_INDENT + aItem[ITEM_Y1]*aPaintRep[FORM_XKOEF]/aPaintRep[FORM_XKOEFCONST]
      y2 := TOP_INDENT + (aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-1)*aPaintRep[FORM_XKOEF]/aPaintRep[FORM_XKOEFCONST]
   ENDIF
   IF y1 >= TOP_INDENT .AND. y1 <= aCoors[4]
      IF aItem[ITEM_STATE] == STATE_SELECTED .OR. aItem[ITEM_STATE] == STATE_PRESSED
         hwg_Fillrect( hDC, x1-3, y1-3, x2+3, y2+3, COLOR_3DLIGHT+1 )
         hwg_Selectobject( hDC, oPenBorder:handle )
         hwg_Rectangle( hDC, x1-3, y1-3, x2+3, y2+3 )
         hwg_Rectangle( hDC, x1-1, y1-1, x2+1, y2+1 )
      ENDIF
      IF aItem[ITEM_TYPE] == TYPE_TEXT
         IF Empty( aItem[ITEM_CAPTION] )
            hwg_Fillrect( hDC, x1, y1, x2, y2, COLOR_3DSHADOW+1 )
         ELSE
      hwg_Selectobject( hDC, Iif(lPreview,oFontSmall:handle,aItem[ITEM_FONT]:handle) )
            hwg_Drawtext( hDC,aItem[ITEM_CAPTION],x1,y1,x2,y2, ;
              Iif(aItem[ITEM_ALIGN]==0,DT_LEFT,Iif(aItem[ITEM_ALIGN]==1,DT_RIGHT,DT_CENTER)) )
         ENDIF
      ELSEIF aItem[ITEM_TYPE] == TYPE_HLINE
         hwg_Selectobject( hDC,aItem[ITEM_PEN]:handle )
         hwg_Drawline( hDC,x1,y1,x2,y1 )
      ELSEIF aItem[ITEM_TYPE] == TYPE_VLINE
         hwg_Selectobject( hDC,aItem[ITEM_PEN]:handle )
         hwg_Drawline( hDC,x1,y1,x1,y2 )
      ELSEIF aItem[ITEM_TYPE] == TYPE_BOX
         hwg_Selectobject( hDC,aItem[ITEM_PEN]:handle )
         hwg_Rectangle( hDC, x1, y1, x2, y2 )
      ELSEIF aItem[ITEM_TYPE] == TYPE_BITMAP
         IF aItem[ITEM_BITMAP] == Nil
            hwg_Fillrect( hDC, x1, y1, x2, y2, COLOR_3DSHADOW+1 )
         ELSE
            hwg_Drawbitmap( hDC, aItem[ITEM_BITMAP]:handle,SRCAND, x1, y1, x2-x1+1, y2-y1+1 )
         ENDIF
      ELSEIF aItem[ITEM_TYPE] == TYPE_MARKER
         hwg_Selectobject( hDC,oPenDivider:handle )
         hwg_Drawline( hDC,LEFT_INDENT,y1,LEFT_INDENT-1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0),y1 )
         hwg_Selectobject( hDC, oFontSmall:handle )
         hwg_Drawtext( hDC,aItem[ITEM_CAPTION],x1,y1,x2,y2,DT_CENTER )
      ENDIF
   ENDIF
Return Nil

Static Function MessagesProc( oWnd, msg, wParam, lParam )
Local i, aItem, hWnd := oWnd:handle

   IF msg == WM_VSCROLL
      Vscroll( hWnd,hwg_Loword( hwg_PtrToUlong( wParam ) ),hwg_Hiword( hwg_PtrToUlong( wParam ) ) )
   ELSEIF msg == WM_MOUSEMOVE
      MouseMove( hwg_PtrToUlong( wParam ), hwg_Loword( lParam ), hwg_Hiword( lParam ) )
   ELSEIF msg == WM_LBUTTONDOWN
      LButtonDown( hwg_Loword( lParam ), hwg_Hiword( lParam ) )
   ELSEIF msg == WM_LBUTTONUP
      LButtonUp( hwg_Loword( lParam ), hwg_Hiword( lParam ) )
   ELSEIF msg == WM_LBUTTONDBLCLK
      LButtonDbl( hwg_Loword( lParam ), hwg_Hiword( lParam ) )
   ELSEIF msg == WM_KEYDOWN
   
      IF  hwg_PtrToUlong( wParam ) == 46
         DeleteItem()
      ELSEIF hwg_PtrToUlong( wParam )  == 34    // PageDown
        VScroll( hWnd, SB_LINEDOWN )
      ELSEIF hwg_PtrToUlong( wParam )  == 33    // PageUp
        VScroll( hWnd, SB_LINEUP )
      ENDIF
   ELSEIF msg == WM_KEYUP
      IF hwg_PtrToUlong( wParam )  == 40        // Down
         FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
            IF aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_SELECTED
               aItem := aPaintRep[FORM_ITEMS,i]
               IF aItem[ITEM_Y1]+aItem[ITEM_HEIGHT] < aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEFCONST]
                  aItem[ITEM_Y1] ++
                  aPaintRep[FORM_CHANGED] := .T.
                  WriteItemInfo( aItem )
                  hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                           TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-4, ;
                           LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                           TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
                  IF aItem[ITEM_TYPE] == TYPE_MARKER
                     hwg_Invalidaterect( hWnd, 0, LEFT_INDENT, ;
                              TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y], ;
                              LEFT_INDENT-1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0), ;
                              TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] )
                  ENDIF
                  hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
               ENDIF
            ENDIF
         NEXT
      ELSEIF hwg_PtrToUlong( wParam )  == 38    // Up
         FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
            IF aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_SELECTED
               aItem := aPaintRep[FORM_ITEMS,i]
               IF aItem[ITEM_Y1] > 1
                  aItem[ITEM_Y1] --
                  aPaintRep[FORM_CHANGED] := .T.
                  WriteItemInfo( aItem )
                  hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                           TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                           LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                           TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+4 )
                  IF aItem[ITEM_TYPE] == TYPE_MARKER
                     hwg_Invalidaterect( hWnd, 0, LEFT_INDENT, ;
                              TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y], ;
                              LEFT_INDENT-1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0), ;
                              TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] )
                  ENDIF
                  hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
               ENDIF
            ENDIF
         NEXT
      ELSEIF hwg_PtrToUlong( wParam )  == 39    // Right
         FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
            IF aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_SELECTED
               aItem := aPaintRep[FORM_ITEMS,i]
               IF aItem[ITEM_TYPE] != TYPE_MARKER .AND. ;
                    aItem[ITEM_X1]+aItem[ITEM_WIDTH] < aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEFCONST]
                  aItem[ITEM_X1] ++
                  aPaintRep[FORM_CHANGED] := .T.
                  WriteItemInfo( aItem )
                  hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-4, ;
                           TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                           LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                           TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
                  hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
               ENDIF
            ENDIF
         NEXT
      ELSEIF hwg_PtrToUlong( wParam )  == 37    // Left
         FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
            IF aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_SELECTED
               aItem := aPaintRep[FORM_ITEMS,i]
               IF aItem[ITEM_TYPE] != TYPE_MARKER .AND. aItem[ITEM_X1] > 1
                  aItem[ITEM_X1] --
                  aPaintRep[FORM_CHANGED] := .T.
                  WriteItemInfo( aItem )
                  hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                           TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                           LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+4, ;
                           TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
                  hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
               ENDIF
            ENDIF
         NEXT
      ENDIF
   ENDIF
Return -1

Static Function VSCROLL( hWnd,nScrollCode, nNewPos )
Local step  := Round(aPaintRep[FORM_XKOEF]*10,0)*2, nsteps := aPaintRep[FORM_Y]/step, kolsteps
Local aCoors := hwg_Getclientrect( hWnd )

   IF nScrollCode == SB_LINEDOWN
      kolsteps := Round( ( Round(aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEF],0)- ;
         (aCoors[4]-aCoors[2]-TOP_INDENT) ) / step, 0 ) + 1
      IF nsteps < kolsteps
         aPaintRep[FORM_Y] += step
         nsteps ++
         IF nsteps>=kolsteps
            hwg_Redrawwindow( hWnd, RDW_ERASE + RDW_INVALIDATE )
         ELSE
            hwg_Invalidaterect( hWnd, 0, 0, TOP_INDENT, aCoors[3], aCoors[4] )
            hwg_Sendmessage( hWnd, WM_PAINT, 0, 0 )
         ENDIF
      ENDIF
   ELSEIF nScrollCode == SB_LINEUP
      IF nsteps > 0
         aPaintRep[FORM_Y] -= step
         hwg_Invalidaterect( hWnd, 0, 0, TOP_INDENT, aCoors[3], aCoors[4] )
         hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
      ENDIF
   ELSEIF nScrollCode == SB_THUMBTRACK
      IF --nNewPos != nsteps
         kolsteps := Round( ( Round(aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEF],0)- ;
            (aCoors[4]-aCoors[2]-TOP_INDENT) ) / step, 0 ) + 1
         aPaintRep[FORM_Y] := nNewPos * step
         IF aPaintRep[FORM_Y]/step>=kolsteps
            hwg_Redrawwindow( hWnd, RDW_ERASE + RDW_INVALIDATE )
         ELSE
            hwg_Invalidaterect( hWnd, 0, 0, TOP_INDENT, aCoors[3], aCoors[4] )
            hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
         ENDIF
      ENDIF
   ENDIF
Return Nil

Static Function MouseMove( wParam, xPos, yPos )
Local x1 := LEFT_INDENT, y1 := TOP_INDENT, x2, y2
Local hWnd
Local aItem, i, dx, dy

   IF aPaintRep == Nil .OR. hwg_Ischeckedmenuitem( ,IDM_VIEW1 )
      Return .T.
   ENDIF
   itemBorder := 0
   x2 := x1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0)-1
   y2 := y1+Round(aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEF],0)-aPaintRep[FORM_Y]-1
   IF nAddItem > 0 
      IF xPos > x1 .AND. xPos < x2 .AND. yPos > y1 .AND. yPos < y2
         Hwg_SetCursor( crossCursor )
      ENDIF
   ELSEIF itemPressed > 0
      IF hwg_Ischeckedmenuitem(,IDM_MOUSE2) .AND. Abs(xPos - mPos[1]) < 3 .AND. Abs(yPos - mPos[2]) < 3
         Return Nil
      ENDIF
      aItem := aPaintRep[FORM_ITEMS,itemPressed]
      IF hwg_Checkbit( hwg_PtrToUlong( wParam ), MK_LBUTTON )
         hWnd := Hwindow():GetMain():handle
         hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                  TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                  LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                  TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
         IF aItem[ITEM_TYPE] == TYPE_MARKER
            hwg_Invalidaterect( hWnd, 0, LEFT_INDENT, ;
                     TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y], ;
                     LEFT_INDENT-1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0), ;
                     TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] )
         ELSE
            aItem[ITEM_X1] += (xPos - mPos[1])
         ENDIF
         aItem[ITEM_Y1] += (yPos - mPos[2])
         hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                  TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                  LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                  TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
         IF aItem[ITEM_TYPE] == TYPE_MARKER
            hwg_Invalidaterect( hWnd, 0, LEFT_INDENT, ;
                     TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y], ;
                     LEFT_INDENT-1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0), ;
                     TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] )
         ENDIF
         mPos[1] := xPos; mPos[2] := yPos
         aPaintRep[FORM_CHANGED] := .T.
         WriteItemInfo( aItem )
         hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
      ELSE
         aItem[ITEM_STATE] := STATE_SELECTED
         itemPressed := 0
      ENDIF
   ELSEIF itemSized > 0
      aItem := aPaintRep[FORM_ITEMS,itemSized]
      IF hwg_Checkbit( hwg_PtrToUlong( wParam ), MK_LBUTTON )
         dx := xPos - mPos[1]
         dy := yPos - mPos[2]
         hWnd := Hwindow():GetMain():handle
         hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                  TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                  LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                  TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
         IF resizeDirection == 1
            IF aItem[ITEM_WIDTH] - dx > 10
               aItem[ITEM_WIDTH] -= dx
               aItem[ITEM_X1] += dx
            ENDIF
         ELSEIF resizeDirection == 2
            IF aItem[ITEM_HEIGHT] - dy > 7
               aItem[ITEM_HEIGHT] -= dy
               aItem[ITEM_Y1] += dy
            ENDIF
         ELSEIF resizeDirection == 3
            IF aItem[ITEM_WIDTH] + dx > 10
               aItem[ITEM_WIDTH] += dx
            ENDIF
         ELSEIF resizeDirection == 4
            IF aItem[ITEM_HEIGHT] + dy > 7
               aItem[ITEM_HEIGHT] += dy
            ENDIF
         ENDIF
         mPos[1] := xPos; mPos[2] := yPos
         hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                  TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                  LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                  TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
         aPaintRep[FORM_CHANGED] := .T.
         WriteItemInfo( aItem )
         Hwg_SetCursor( Iif( resizeDirection==1.OR.resizeDirection==3,horzCursor,vertCursor ) )
         hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
      ENDIF
   ELSE
      FOR i := Len( aPaintRep[FORM_ITEMS] ) TO 1 STEP -1
         aItem := aPaintRep[FORM_ITEMS,i]
         IF aItem[ITEM_STATE] == STATE_SELECTED
            IF xPos >= LEFT_INDENT-2+aItem[ITEM_X1] .AND. ;
                xPos < LEFT_INDENT+1+aItem[ITEM_X1] .AND. ;
                yPos >= TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] .AND. yPos < TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]+aItem[ITEM_HEIGHT]
               IF aItem[ITEM_TYPE] != TYPE_VLINE .AND. aItem[ITEM_TYPE] != TYPE_MARKER
                  Hwg_SetCursor( horzCursor )
                  itemBorder := i
                  resizeDirection := 1
               ENDIF
            ELSEIF xPos >= LEFT_INDENT-1+aItem[ITEM_X1]+aItem[ITEM_WIDTH] .AND. ;
                xPos < LEFT_INDENT+2+aItem[ITEM_X1]+aItem[ITEM_WIDTH] .AND. ;
                yPos >= TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] .AND. yPos < LEFT_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]+aItem[ITEM_HEIGHT]
               IF aItem[ITEM_TYPE] != TYPE_VLINE .AND. aItem[ITEM_TYPE] != TYPE_MARKER
                  Hwg_SetCursor( horzCursor )
                  itemBorder := i
                  resizeDirection := 3
               ENDIF
            ELSEIF yPos >= TOP_INDENT-2+aItem[ITEM_Y1]-aPaintRep[FORM_Y] .AND. ;
                yPos < TOP_INDENT+1+aItem[ITEM_Y1]-aPaintRep[FORM_Y] .AND. ;
                xPos >= LEFT_INDENT+aItem[ITEM_X1] .AND. xPos < LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]
               IF aItem[ITEM_TYPE] != TYPE_HLINE .AND. aItem[ITEM_TYPE] != TYPE_MARKER
                  Hwg_SetCursor( vertCursor )
                  itemBorder := i
                  resizeDirection := 2
               ENDIF
            ELSEIF yPos >= TOP_INDENT-1+aItem[ITEM_Y1]-aPaintRep[FORM_Y]+aItem[ITEM_HEIGHT] .AND. ;
                yPos < TOP_INDENT+2+aItem[ITEM_Y1]-aPaintRep[FORM_Y]+aItem[ITEM_HEIGHT] .AND. ;
                xPos >= LEFT_INDENT+aItem[ITEM_X1] .AND. xPos < LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]
               IF aItem[ITEM_TYPE] != TYPE_HLINE .AND. aItem[ITEM_TYPE] != TYPE_MARKER
                  Hwg_SetCursor( vertCursor )
                  itemBorder := i
                  resizeDirection := 4
               ENDIF
            ENDIF
            IF itemBorder != 0
               EXIT
            ENDIF
         ENDIF
      NEXT
   ENDIF
Return Nil

Static Function LButtonDown( xPos, yPos )
Local i, aItem, res := .F.
Local hWnd := Hwindow():GetMain():handle
   IF aPaintRep == Nil .OR. hwg_Ischeckedmenuitem( ,IDM_VIEW1 )
      Return .T.
   ENDIF
   IF nAddItem > 0
   ELSEIF itemBorder != 0
      itemSized := itemBorder
      mPos[1] := xPos; mPos[2] := yPos
      Hwg_SetCursor( Iif( resizeDirection==1.OR.resizeDirection==3,horzCursor,vertCursor ) )
   ELSE
      IF ( i := DeselectAll() ) != 0
         hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aPaintRep[FORM_ITEMS,i,ITEM_X1]-3, ;
            TOP_INDENT+aPaintRep[FORM_ITEMS,i,ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
            LEFT_INDENT+aPaintRep[FORM_ITEMS,i,ITEM_X1]+aPaintRep[FORM_ITEMS,i,ITEM_WIDTH]+3, ;
            TOP_INDENT+aPaintRep[FORM_ITEMS,i,ITEM_Y1]+aPaintRep[FORM_ITEMS,i,ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
         res := .T.
      ENDIF
      hwg_WriteStatus( Hwindow():GetMain(),1,"" )
      FOR i := Len( aPaintRep[FORM_ITEMS] ) TO 1 STEP -1
         aItem := aPaintRep[FORM_ITEMS,i]
         IF xPos >= LEFT_INDENT+aItem[ITEM_X1] ;
              .AND. xPos < LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH] ;
              .AND. yPos > TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y] ;
              .AND. yPos < TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]+aItem[ITEM_HEIGHT]
            aPaintRep[FORM_ITEMS,i,ITEM_STATE] := STATE_PRESSED
            itemPressed := i
            mPos[1] := xPos; mPos[2] := yPos
            WriteItemInfo( aItem )
            hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                     TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                     LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                     TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
            res := .T.
            EXIT
         ENDIF
      NEXT
      IF res
         hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
      ENDIF
   ENDIF
Return Nil

Static Function LButtonUp( xPos, yPos )
Local x1 := LEFT_INDENT, y1 := TOP_INDENT, x2, y2, aItem
Local hWnd := Hwindow():GetMain():handle
   IF aPaintRep == Nil .OR. hwg_Ischeckedmenuitem( ,IDM_VIEW1 )
      Return .T.
   ENDIF
   x2 := x1+Round(aPaintRep[FORM_WIDTH]*aPaintRep[FORM_XKOEF],0)-1
   y2 := y1+Round(aPaintRep[FORM_HEIGHT]*aPaintRep[FORM_XKOEF],0)-aPaintRep[FORM_Y]-1
   IF nAddItem > 0 .AND. xPos > x1 .AND. xPos < x2 .AND. yPos > y1 .AND. yPos < y2
      Aadd( aPaintRep[FORM_ITEMS], { nAddItem,"",xPos-x1, ;
           yPos-y1+aPaintRep[FORM_Y], aInitialSize[nAddItem,1], ;
           aInitialSize[nAddItem,2],0,Nil,Nil,0,0,Nil,STATE_SELECTED } )
      aItem := Atail( aPaintRep[FORM_ITEMS] )
      IF nAddItem == TYPE_HLINE .OR. nAddItem == TYPE_VLINE .OR. nAddItem == TYPE_BOX
         aItem[ITEM_PEN] := HPen():Add()
      ELSEIF nAddItem == TYPE_TEXT
         aItem[ITEM_FONT] := ;
                 Iif( lastFont==Nil,HFont():Add( "Arial",0,-13 ),lastFont )
      ELSEIF nAddItem == TYPE_MARKER
         aItem[ITEM_X1] := -aInitialSize[nAddItem,1]
         aItem[ITEM_CAPTION] := aMarkers[ nMarkerType ]
      ENDIF
      DeselectAll( Len( aPaintRep[FORM_ITEMS] ) )
      aPaintRep[FORM_CHANGED] := .T.
      WriteItemInfo( Atail( aPaintRep[FORM_ITEMS] ) )
      hwg_WriteStatus( Hwindow():GetMain(),2,Ltrim(Str(aPaintRep[FORM_WIDTH],4))+"x"+ ;
         Ltrim(Str(aPaintRep[FORM_HEIGHT],4))+"  Items: "+Ltrim(Str(Len(aPaintRep[FORM_ITEMS]))) )
      hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
               TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
               LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
               TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
      hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
      IF Len( aPaintRep[FORM_ITEMS] ) == 1
         hwg_Enablemenuitem( ,IDM_CLOSE, .T., .T. )
         hwg_Enablemenuitem( ,IDM_SAVE, .T., .T. )
         hwg_Enablemenuitem( ,IDM_SAVEAS, .T., .T. )
         hwg_Enablemenuitem( ,IDM_PRINT, .T., .T. )
         hwg_Enablemenuitem( ,IDM_PREVIEW, .T., .T. )
         hwg_Enablemenuitem( ,IDM_FOPT, .T., .T. )
      ENDIF
   ELSEIF itemPressed > 0
      aPaintRep[FORM_ITEMS,itemPressed,ITEM_STATE] := STATE_SELECTED
   ENDIF
   IF itemPressed > 0 .OR. itemSized > 0 .OR. nAddItem > 0
      aPaintRep[FORM_ITEMS] := Asort( aPaintRep[FORM_ITEMS],,, {|z,y|z[ITEM_Y1]<y[ITEM_Y1].OR.(z[ITEM_Y1]==y[ITEM_Y1].AND.z[ITEM_X1]<y[ITEM_X1]).OR.(z[ITEM_Y1]==y[ITEM_Y1].AND.z[ITEM_X1]==y[ITEM_X1].AND.(z[ITEM_WIDTH]<y[ITEM_WIDTH].OR.z[ITEM_HEIGHT]<y[ITEM_HEIGHT]))} )
   ENDIF
   itemPressed := itemSized := itemBorder := nAddItem := 0
Return Nil

Static Function DeleteItem()
Local hWnd := Hwindow():GetMain():handle
Local i, aItem
   FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
      IF aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_SELECTED
         aItem := aPaintRep[FORM_ITEMS,i]
         IF aItem[ITEM_PEN] != Nil
            aItem[ITEM_PEN]:Release()
         ENDIF
         hwg_Invalidaterect( hWnd, 0, LEFT_INDENT+aItem[ITEM_X1]-3, ;
                  TOP_INDENT+aItem[ITEM_Y1]-aPaintRep[FORM_Y]-3, ;
                  LEFT_INDENT+aItem[ITEM_X1]+aItem[ITEM_WIDTH]+3, ;
                  TOP_INDENT+aItem[ITEM_Y1]+aItem[ITEM_HEIGHT]-aPaintRep[FORM_Y]+3 )
         Adel( aPaintRep[FORM_ITEMS],i )
         Asize( aPaintRep[FORM_ITEMS], Len( aPaintRep[FORM_ITEMS] ) - 1 )
         aPaintRep[FORM_CHANGED] := .T.
         hwg_WriteStatus( Hwindow():GetMain(),1,"" )
         hwg_WriteStatus( Hwindow():GetMain(),2,Ltrim(Str(aPaintRep[FORM_WIDTH],4))+"x"+ ;
                 Ltrim(Str(aPaintRep[FORM_HEIGHT],4))+"  Items: "+Ltrim(Str(Len(aPaintRep[FORM_ITEMS]))) )
         IF Len( aPaintRep[FORM_ITEMS] ) == 0
            hwg_Enablemenuitem( ,IDM_CLOSE, .F., .T. )
            hwg_Enablemenuitem( ,IDM_SAVE, .F., .T. )
            hwg_Enablemenuitem( ,IDM_SAVEAS, .F., .T. )
            hwg_Enablemenuitem( ,IDM_PRINT, .F., .T. )
            hwg_Enablemenuitem( ,IDM_PREVIEW, .F., .T. )
            hwg_Enablemenuitem( ,IDM_FOPT, .F., .T. )
         ENDIF
         hwg_Postmessage( hWnd, WM_PAINT, 0, 0 )
         EXIT
      ENDIF
   NEXT
Return Nil

Static Function DeselectAll( iSelected )
Local i, iPrevSelected := 0
   iSelected := Iif( iSelected == Nil,0,iSelected )
   FOR i := 1 TO Len( aPaintRep[FORM_ITEMS] )
      IF aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_SELECTED .OR. ;
           aPaintRep[FORM_ITEMS,i,ITEM_STATE] == STATE_PRESSED
         iPrevSelected := i
      ENDIF
      IF iSelected != i
         aPaintRep[FORM_ITEMS,i,ITEM_STATE] := STATE_NORMAL
      ENDIF
   NEXT
Return iPrevSelected

Static Function WriteItemInfo( aItem )
   hwg_WriteStatus( Hwindow():GetMain(),1," x1: "+Ltrim(Str(aItem[ITEM_X1]))+", y1: " ;
          +Ltrim(Str(aItem[ITEM_Y1]))+", cx: "+Ltrim(Str(aItem[ITEM_WIDTH])) ;
          +", cy: "+Ltrim(Str(aItem[ITEM_HEIGHT])) )
Return Nil
