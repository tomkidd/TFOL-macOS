//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2Console.h"
//
// Written by:	Knightmare 	[http://kmquake2.quakedev.com].
//
// Quake II™ is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>
#import "Quake2.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface Quake2 (Console)

-(void) ShowConsole: (BOOL) show;
-(void) ShowError: (char *) theString;
-(void) FlashErrorText: (NSTimer *) theTimer;
-(void) OutputToConsole: (char *) theString;
-(IBAction) CopyClicked: (id) theSender;
-(IBAction) ClearClicked: (id) theSender;
-(IBAction) QuitClicked: (id) theSender;

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
