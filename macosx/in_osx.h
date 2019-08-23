//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "in_osx.h"
//
// Written by:	awe                         [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo   [http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Defines

// Knightmare added- for mouse event handling
#define	SYS_MOUSE_BUTTONS				5							// number of supported mouse buttons [max. 32].

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

extern UInt8		gInSpecialKey[];
extern UInt8		gInNumPadKey[];

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

// Knightmare added
void	IN_MouseEvent (UInt32 myMouseButtons, int sysMsgTime);

//------------------------------------------------------------------------------------------------------------------------------------------------------------
