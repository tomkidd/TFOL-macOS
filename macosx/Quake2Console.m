//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2Console.m"
//
// Written by:	Knightmare 	[http://kmquake2.quakedev.com].
//
// Quake II™ is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import "Quake2.h"
#import "Quake2Console.h"
#import "sys_osx.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation Quake2 (Console)


//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(void) ShowConsole: (BOOL) show
{
	NSWindow	*conWindow = [[NSApp delegate] ConsoleWindow];
	
	if (!show)
	{
		[conWindow orderOut: nil];
		return;
	}
	
	[consoleWindow center];
	[consoleWindow makeKeyAndOrderFront: nil];
	[consoleWindow makeFirstResponder: consoleInputField];
//	[consoleInputField setFont: [NSFont fontWithName: @"CourierNewPSMT" size: 12.0]];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(void) ShowError: (char *) theString
{
	[consoleErrorField setHidden: NO];
	[consoleErrorField setStringValue: [NSString stringWithFormat:@"%s", theString]];
	[consoleErrorField setFont: [NSFont fontWithName: @"CourierNewPSMT" size: 12.0]];
	[consoleErrorField setTextColor:[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0]];
	[consoleWindow makeFirstResponder: consoleTextOutput];
	[consoleInputField setHidden: YES];
	[consoleInputField setEnabled: NO];
	consoleFlashColor = false;
	consoleErrorTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0f
														 target: self
													   selector: @selector (FlashErrorText:)
													   userInfo: NULL
														repeats: YES];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(void) FlashErrorText: (NSTimer *) theTimer
{
	consoleFlashColor = !consoleFlashColor;
	
	if (consoleFlashColor)
		[consoleErrorField setTextColor:[NSColor colorWithDeviceRed: 1.0 green: 0.0 blue: 0.0 alpha: 1.0]];
	else
		[consoleErrorField setTextColor:[NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0]];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(void) OutputToConsole: (char *) theString
{
	char				buffer[SYS_STRING_SIZE];
	int					len = 0;
	NSTextStorage		*storage;
	NSFont				*font;
	NSColor				*color;
	NSMutableDictionary			*dictionary;
	NSMutableAttributedString	*atrString;
	NSRange				range;
	
    if (strlen(theString) > SYS_STRING_SIZE)
    {
        abort();
    }
    
	// Change \n to \r\n so it displays properly in the edit box and
	// remove color escapes
	while (*theString)
	{
		if (*theString == '\n'){
			buffer[len++] = '\r';
			buffer[len++] = '\n';
		}
		else if (Q_IsColorString(theString))
			theString++;
		else
			buffer[len++] = *theString;
		
		theString++;
	}
	buffer[len] = 0;
	
	storage = [consoleTextOutput textStorage];
	[storage beginEditing];
	
	font = [NSFont fontWithName: @"CourierNewPSMT" size: 12.0];
	color = [NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0];
	dictionary = [[NSMutableDictionary alloc] init];
	[dictionary setObject: font forKey: NSFontAttributeName];
	[dictionary setObject: color forKey: NSForegroundColorAttributeName];
	atrString = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat:@"%s", buffer] attributes: dictionary];
	[storage appendAttributedString: atrString];
	[atrString release];
	[dictionary release];
	
	[storage endEditing];
	
	// scroll to end
	range = NSMakeRange([[consoleTextOutput string] length], 0);
	[consoleTextOutput scrollRangeToVisible: range];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(void) controlTextDidEndEditing: (NSNotification *) theNotification
{
	NSDictionary	*dict = [theNotification userInfo];
	NSNumber		*mvmt = [dict objectForKey: @"NSTextMovement"];
	int				code = [mvmt intValue];
	
	if ([theNotification object] == consoleInputField)
	{
		if (code == NSReturnTextMovement)
		{
			strncpy(consoleCmdBuffer, [[consoleInputField stringValue] cString], sizeof(consoleCmdBuffer));
			[consoleInputField setStringValue: @""];
			
			Com_Printf("]%s\n", consoleCmdBuffer);
		}
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(IBAction) CopyClicked: (id) theSender
{
	NSPasteboard		*thePasteboard = NULL;
	
	if ([[consoleTextOutput string] length] > 0)
	{
		thePasteboard = [NSPasteboard generalPasteboard];
		[thePasteboard clearContents];
		[thePasteboard declareTypes: [NSArray arrayWithObjects: NSStringPboardType,nil] owner: nil];
		[thePasteboard setString: [consoleTextOutput string] forType: NSStringPboardType];
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(IBAction) ClearClicked: (id) theSender
{
	[consoleTextOutput setString: @""];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(IBAction) QuitClicked: (id) theSender
{
	Com_Quit ();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
