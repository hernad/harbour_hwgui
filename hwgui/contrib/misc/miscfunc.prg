/*
 *$Id: miscfunc.prg 2210 2013-12-10 09:58:47Z alkresin $
 */

FUNCTION ADDMETHOD( oObjectName, cMethodName, pFunction )

   IF ValType( oObjectName ) = "O" .AND. ! Empty( cMethodName )
      IF ! __ObjHasMsg( oObjectName, cMethodName )
         __objAddMethod( oObjectName, cMethodName, pFunction )
      ENDIF
      RETURN .T.
   ENDIF 

   RETURN .F.

FUNCTION ADDPROPERTY( oObjectName, cPropertyName, eNewValue )

   IF ValType( oObjectName ) = "O" .AND. ! Empty( cPropertyName )
      IF ! __objHasData( oObjectName, cPropertyName )
         IF Empty( __objAddData( oObjectName, cPropertyName ) )
            RETURN .F.
         ENDIF
      ENDIF
      IF !Empty( eNewValue )
         IF ValType( eNewValue ) = "B"
            oObjectName: & ( cPropertyName ) := Eval( eNewValue )
         ELSE
            oObjectName: & ( cPropertyName ) := eNewValue
         ENDIF
      ENDIF
      RETURN .T.
   ENDIF

   RETURN .F.

FUNCTION REMOVEPROPERTY( oObjectName, cPropertyName )

   IF ValType( oObjectName ) = "O" .AND. ! Empty( cPropertyName ) .AND. ;
         __objHasData( oObjectName, cPropertyName )
      RETURN Empty( __objDelData( oObjectName, cPropertyName ) )
   ENDIF

   RETURN .F.

FUNCTION hwg_TxtRect( cTxt, oWin, oFont )

   LOCAL hDC
   LOCAL ASize
   LOCAL hFont

   oFont := iif( oFont != Nil, oFont, oWin:oFont )

   hDC       := hwg_Getdc( oWin:handle )
   IF oFont == Nil .AND. oWin:oParent != Nil
      oFont := oWin:oParent:oFont
   ENDIF
   IF oFont != Nil
      hFont := hwg_Selectobject( hDC, oFont:handle )
   ENDIF
   ASize     := hwg_Gettextsize( hDC, cTxt )
   IF oFont != Nil
      hwg_Selectobject( hDC, hFont )
   ENDIF
   hwg_Releasedc( oWin:handle, hDC )

   RETURN ASize

FUNCTION hwg_SetAll( oWnd, cProperty, Value, aControls, cClass )

   // cProperty Specifies the property to be set.
   // Value Specifies the new setting for the property. The data type of Value depends on the property being set.
   //aControls - property of the Control with objectos inside
   // cClass baseclass hwgui
   LOCAL nLen , i

   aControls := iif( Empty( aControls ), oWnd:aControls, aControls )
   nLen := iif( ValType( aControls ) = "C", Len( oWnd:&aControls ), Len( aControls ) )
   FOR i = 1 TO nLen
      IF ValType( aControls ) = "C"
         oWnd:&aControls[ i ]:&cProperty := Value
      ELSEIF cClass == Nil .OR. Upper( cClass ) == aControls[ i ]:ClassName
         IF Value = Nil
            __mvPrivate( "oCtrl" )
            &( "oCtrl" ) := aControls[ i ]
            &( "oCtrl:" + cProperty )
         ELSE
            aControls[ i ]:&cProperty := Value
         ENDIF
      ENDIF
   NEXT

   RETURN Nil
