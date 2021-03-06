/*
Copyright (C) 1997-2001 Id Software, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

// ui_game_credits.c -- the credits scroll

#include <ctype.h>
#ifdef _WIN32
#include <io.h>
#endif
#include "../client/client.h"
#include "ui_local.h"

/*
=============================================================================

CREDITS MENU

=============================================================================
*/
static int credits_start_time;
// Knigthtmare added- allow credits to scroll past top of screen
static int credits_start_line;
static const char **credits;
static char *creditsIndex[256];
//static char *creditsBuffer;
static const char *idcredits[] =
{
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"QUAKE II BY ID SOFTWARE",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"PROGRAMMING",
	"John Carmack",
	"John Cash",
	"Brian Hook",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ART",
	"Adrian Carmack",
	"Kevin Cloud",
	"Paul Steed",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"LEVEL DESIGN",
	"Tim Willits",
	"American McGee",
	"Christian Antkow",
	"Paul Jaquays",
	"Brandon James",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"BIZ",
	"Todd Hollenshead",
	"Barrett (Bear) Alexander",
	"Donna Jackson",
	"",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SPECIAL THANKS",
	"Ben Donges for beta testing",
	"",
	"",
	"",
	"",
	"",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ADDITIONAL SUPPORT",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"LINUX PORT AND CTF",
	"Dave \"Zoid\" Kirsch",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"CINEMATIC SEQUENCES",
	"Ending Cinematic by Blur Studio - ",
	"Venice, CA",
	"",
	"Environment models for Introduction",
	"Cinematic by Karl Dolgener",
	"",
	"Assistance with environment design",
	"by Cliff Iwai",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SOUND EFFECTS AND MUSIC",
	"Sound Design by Soundelux Media Labs.",
	"Music Composed and Produced by",
	"Soundelux Media Labs.  Special thanks",
	"to Bill Brown, Tom Ozanich, Brian",
	"Celano, Jeff Eisner, and The Soundelux",
	"Players.",
	"",
	"\"Level Music\" by Sonic Mayhem",
	"www.sonicmayhem.com",
	"",
	"\"Quake II Theme Song\"",
	"(C) 1997 Rob Zombie. All Rights",
	"Reserved.",
	"",
	"Track 10 (\"Climb\") by Jer Sypult",
	"",
	"Voice of computers by",
	"Carly Staehlin-Taylor",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"THANKS TO ACTIVISION",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"IN PARTICULAR:",
	"",
	"John Tam",
	"Steve Rosenthal",
	"Marty Stratton",
	"Henk Hartong",
	"",
	"Quake II(tm) (C)1997 Id Software, Inc.",
	"All Rights Reserved.  Distributed by",
	"Activision, Inc. under license.",
	"Quake II(tm), the Id Software name,",
	"the \"Q II\"(tm) logo and id(tm)",
	"logo are trademarks of Id Software,",
	"Inc. Activision(R) is a registered",
	"trademark of Activision, Inc. All",
	"other trademarks and trade names are",
	"properties of their respective owners.",
	0
};

static const char *xatcredits[] =
{
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"QUAKE II MISSION PACK: THE RECKONING",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"BY",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"XATRIX ENTERTAINMENT, INC.",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"DESIGN AND DIRECTION",
	"Drew Markham",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"PRODUCED BY",
	"Greg Goodrich",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"PROGRAMMING",
	"Rafael Paiz",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"LEVEL DESIGN / ADDITIONAL GAME DESIGN",
	"Alex Mayberry",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"LEVEL DESIGN",
	"Mal Blackwell",
	"Dan Koppel",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ART DIRECTION",
	"Michael \"Maxx\" Kaufman",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"COMPUTER GRAPHICS SUPERVISOR AND",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"CHARACTER ANIMATION DIRECTION",
	"Barry Dempsey",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SENIOR ANIMATOR AND MODELER",
	"Jason Hoover",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"CHARACTER ANIMATION AND",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"MOTION CAPTURE SPECIALIST",
	"Amit Doron",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ART",
	"Claire Praderie-Markham",
	"Viktor Antonov",
	"Corky Lehmkuhl",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"INTRODUCTION ANIMATION",
	"Dominique Drozdz",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ADDITIONAL LEVEL DESIGN",
	"Aaron Barber",
	"Rhett Baldwin",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"3D CHARACTER ANIMATION TOOLS",
	"Gerry Tyra, SA Technology",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ADDITIONAL EDITOR TOOL PROGRAMMING",
	"Robert Duffy",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ADDITIONAL PROGRAMMING",
	"Ryan Feltrin",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"PRODUCTION COORDINATOR",
	"Victoria Sylvester",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SOUND DESIGN",
	"Gary Bradfield",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"MUSIC BY",
	"Sonic Mayhem",
	"",
	"",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SPECIAL THANKS",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"TO",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"OUR FRIENDS AT ID SOFTWARE",
	"",
	"John Carmack",
	"John Cash",
	"Brian Hook",
	"Adrian Carmack",
	"Kevin Cloud",
	"Paul Steed",
	"Tim Willits",
	"Christian Antkow",
	"Paul Jaquays",
	"Brandon James",
	"Todd Hollenshead",
	"Barrett (Bear) Alexander",
	"Dave \"Zoid\" Kirsch",
	"Donna Jackson",
	"",
	"",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"THANKS TO ACTIVISION",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"IN PARTICULAR:",
	"",
	"Marty Stratton",
	"Henk \"The Original Ripper\" Hartong",
	"Kevin Kraff",
	"Jamey Gottlieb",
	"Chris Hepburn",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"AND THE GAME TESTERS",
	"",
	"Tim Vanlaw",
	"Doug Jacobs",
	"Steven Rosenthal",
	"David Baker",
	"Chris Campbell",
	"Aaron Casillas",
	"Steve Elwell",
	"Derek Johnstone",
	"Igor Krinitskiy",
	"Samantha Lee",
	"Michael Spann",
	"Chris Toft",
	"Juan Valdes",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"THANKS TO INTERGRAPH COMPUTER SYTEMS",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"IN PARTICULAR:",
	"",
	"Michael T. Nicolaou",
	"",
	"",
	"Quake II Mission Pack: The Reckoning",
	"(tm) (C)1998 Id Software, Inc. All",
	"Rights Reserved. Developed by Xatrix",
	"Entertainment, Inc. for Id Software,",
	"Inc. Distributed by Activision Inc.",
	"under license. Quake(R) is a",
	"registered trademark of Id Software,",
	"Inc. Quake II Mission Pack: The",
	"Reckoning(tm), Quake II(tm), the Id",
	"Software name, the \"Q II\"(tm) logo",
	"and id(tm) logo are trademarks of Id",
	"Software, Inc. Activision(R) is a",
	"registered trademark of Activision,",
	"Inc. Xatrix(R) is a registered",
	"trademark of Xatrix Entertainment,",
	"Inc. All other trademarks and trade",
	"names are properties of their",
	"respective owners.",
	0
};

static const char *roguecredits[] =
{
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"QUAKE II MISSION PACK 2: GROUND ZERO",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"BY",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ROGUE ENTERTAINMENT, INC.",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"PRODUCED BY",
	"Jim Molinets",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"PROGRAMMING",
	"Peter Mack",
	"Patrick Magruder",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"LEVEL DESIGN",
	"Jim Molinets",
	"Cameron Lamprecht",
	"Berenger Fish",
	"Robert Selitto",
	"Steve Tietze",
	"Steve Thoms",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ART DIRECTION",
	"Rich Fleider",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ART",
	"Rich Fleider",
	"Steve Maines",
	"Won Choi",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ANIMATION SEQUENCES",
	"Creat Studios",
	"Steve Maines",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"ADDITIONAL LEVEL DESIGN",
	"Rich Fleider",
	"Steve Maines",
	"Peter Mack",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SOUND",
	"James Grunke",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"GROUND ZERO THEME",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"AND",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"MUSIC BY",
	"Sonic Mayhem",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"VWEP MODELS",
	"Brent \"Hentai\" Dill",
	"",
	"",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"SPECIAL THANKS",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"TO",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"OUR FRIENDS AT ID SOFTWARE",
	"",
	"John Carmack",
	"John Cash",
	"Brian Hook",
	"Adrian Carmack",
	"Kevin Cloud",
	"Paul Steed",
	"Tim Willits",
	"Christian Antkow",
	"Paul Jaquays",
	"Brandon James",
	"Todd Hollenshead",
	"Barrett (Bear) Alexander",
	"Katherine Anna Kang",
	"Donna Jackson",
	"Dave \"Zoid\" Kirsch",
	"",
	"",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"THANKS TO ACTIVISION",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"IN PARTICULAR:",
	"",
	"Marty Stratton",
	"Henk Hartong",
	"Mitch Lasky",
	"Steve Rosenthal",
	"Steve Elwell",
	"",
	S_COLOR_BOLD S_COLOR_SHADOW S_COLOR_ALT"AND THE GAME TESTERS",
	"",
	"The Ranger Clan",
	"Dave \"Zoid\" Kirsch",
	"Nihilistic Software",
	"Robert Duffy",
	"",
	"And Countless Others",
	"",
	"",
	"",
	"Quake II Mission Pack 2: Ground Zero",
	"(tm) (C)1998 Id Software, Inc. All",
	"Rights Reserved. Developed by Rogue",
	"Entertainment, Inc. for Id Software,",
	"Inc. Distributed by Activision Inc.",
	"under license. Quake(R) is a",
	"registered trademark of Id Software,",
	"Inc. Quake II Mission Pack 2: Ground",
	"Zero(tm), Quake II(tm), the Id",
	"Software name, the \"Q II\"(tm) logo",
	"and id(tm) logo are trademarks of Id",
	"Software, Inc. Activision(R) is a",
	"registered trademark of Activision,",
	"Inc. Rogue(R) is a registered",
	"trademark of Rogue Entertainment,",
	"Inc. All other trademarks and trade",
	"names are properties of their",
	"respective owners.",
	0
};

int stringLengthExtra ( const char *string);
void M_Credits_MenuDraw( void )
{

	


	float alpha, time = (cls.realtime - credits_start_time) * 0.05;
	int i, y, x, len, specialOffset;

	int leftMargin = 20;
	int leftIndent = 30;

	int specialThanksOffset = 40;

	
	Menu_DrawString( leftMargin,  15, "^0Blendo Games presents", 255);
	Menu_DrawString( leftMargin + 175,  15, "CITIZEN ABEL: ^9THIRTY FLIGHTS OF LOVING", 255);

	//float x, float y, float width, float height, scralign_t align, int red, int green, int blue, int alpha)
	//SCR_DrawFill( 25, 60, 550, 4, ALIGN_STRETCH, 255,128,0, 254 );

	Menu_DrawString(leftMargin, 40, "^7CREATED BY", 128);
	Menu_DrawString(leftIndent, 50, " ^7Brendon Chung", 255);	Menu_DrawString(210, 50, "^7blendogames.com", 128);


	//SCR_DrawFill2( 25, 110, 540, 2, ALIGN_STRETCH, 255,128,0, 160 );
	

	Menu_DrawString(leftMargin, 80, "^7POWERED BY", 128);
	Menu_DrawString(leftIndent, 90, "^7Lazarus", 255);		Menu_DrawString(210, 90, "^7David Hyde & Mad Dog", 128);
	Menu_DrawString(leftIndent, 100, "^7KMQuake II", 255);		Menu_DrawString(210, 100, "^7markshan.com/knightmare", 128);
	Menu_DrawString(leftIndent, 110, "^7Quake II", 255);		Menu_DrawString(210, 110, "^7idsoftware.com", 128);


	//SCR_DrawFill2( 25, 180, 540, 2, ALIGN_STRETCH, 255,128,0, 160 );


	// AUDIO

	Menu_DrawString(leftMargin, 140, "^7MUSIC BY", 128);
	Menu_DrawString(leftIndent, 150, "^7Chris Remo", 255);				Menu_DrawString(210, 150, "^7about.me/chrisremo", 128);

	


	Menu_DrawString(leftMargin, 180, "^7SOUND LIBRARY", 128);
	Menu_DrawString(leftIndent, 190, "^7Soundsnap", 255);					Menu_DrawString(210, 190, "^7soundsnap.com", 128);


	Menu_DrawString(leftMargin, 220, "^7ADDITIONAL AUDIO", 128);
	Menu_DrawString(leftIndent, 230, "^7Jared Emerson-Johnson", 255);		Menu_DrawString(210, 230, "^7basound.com", 128);
	Menu_DrawString(leftIndent, 240, "^7AJ Locascio", 255);				Menu_DrawString(210, 240, "^7brontoco.com", 128);


	

	Menu_DrawString(leftMargin , 270, "^7SPECIAL THANKS", 128);

	Menu_DrawString(leftIndent , 280, "^7Brian Chan", 255);			Menu_DrawString(210, 280, "^7bchan.org", 128);
	Menu_DrawString(leftIndent , 290, "^7Dustin Darcy", 255);
	Menu_DrawString(leftIndent , 300, "^7MJ Kwan", 255);
	Menu_DrawString(leftIndent , 310, "^7Mimi Kwan", 255);
	Menu_DrawString(leftIndent , 320, "^7Mike Tipul", 255);			Menu_DrawString(210, 320, "^7nukeitfromorbit.tv", 128);	
	Menu_DrawString(leftIndent , 330, "^7Neil Mehta", 255);
	Menu_DrawString(leftIndent , 340, "^7Rob MacBride", 255);		Menu_DrawString(210, 340, "^7cargocollective.com/robmacbfolio", 128);
	Menu_DrawString(leftIndent , 350, "^7Robert Yang", 255);			Menu_DrawString(210, 350, "^7blog.radiator.debacle.us", 128);
	Menu_DrawString(leftIndent , 360, "^7Sanjay Madhav", 255);
	Menu_DrawString(leftIndent , 370, "^7Ty Taylor", 255);			Menu_DrawString(210, 370, "^7tytaylor.info", 128);
	Menu_DrawString(leftIndent , 380, "^7Wallace Huang", 255);
	Menu_DrawString(leftIndent , 390, "^7Owen Macindoe", 255);		Menu_DrawString(210, 390, "^7people.csail.mit.edu/owenm", 128);

	
    
	Menu_DrawString(leftMargin , 420, "^7MAC PORT", 128);
    
	Menu_DrawString(leftIndent , 430, "^7fruitz-of-dojo.de", 255);	
    Menu_DrawString(leftIndent , 440, "^7Corwin Light-Williams", 255);	
	


	return;
	//Com_Printf("credits\n");


	if ((viddef.height - ((cls.realtime - credits_start_time)/40.0F)
		+ credits_start_line * SCR_ScaledVideo(MENU_LINE_SIZE)) < 0)
	{
		credits_start_line++;
		if (!credits[credits_start_line])
		{
			credits_start_line = 0;
			credits_start_time = cls.realtime;
		}
	}

	//
	// draw the credits
	//
	for (i=credits_start_line, y=viddef.height - ((cls.realtime - credits_start_time)/40.0F) + credits_start_line * SCR_ScaledVideo(MENU_LINE_SIZE);
		credits[i] && y < viddef.height; y += SCR_ScaledVideo(MENU_LINE_SIZE), i++)
	{
		//int j;
		int	stringoffset = 0;
		int bold = false;

		if ( y <= -MENU_FONT_SIZE )
			continue;
		if ( y > viddef.height )
			continue;

		if ( credits[i][0] == '+' )
		{
			bold = true;
			stringoffset = 1;
		}
		else
		{
			bold = false;
			stringoffset = 0;
		}

		if (y > 7*viddef.height/8)
		{
			float y_test, h_test;
			y_test = y - (7.0/8.0)*viddef.height;
			h_test = viddef.height/8;

			alpha = 1 - (y_test/h_test);

			if (alpha>1) alpha=1; if (alpha<0) alpha=0;
		}
		else if (y < viddef.height/8)
		{
			float y_test, h_test;
			y_test = y;
			h_test = viddef.height/8;

			alpha = y_test/h_test;

			if (alpha>1) alpha=1; if (alpha<0) alpha=0;
		}
		else
			alpha = 1;

		len = strlen(credits[i]) - stringLengthExtra(credits[i]);

		x = ( viddef.width - len * SCR_ScaledVideo(MENU_FONT_SIZE)
				- stringoffset * SCR_ScaledVideo(MENU_FONT_SIZE) ) / 2
			+ ( stringoffset ) * SCR_ScaledVideo(MENU_FONT_SIZE);
		Menu_DrawString(x, y, credits[i], alpha*255);
	}
}

const char *M_Credits_Key( int key )
{
	char *sound = NULL;

	switch (key)
	{
	case K_SPACE:
	case K_ENTER:
	case K_ESCAPE:
	//case K_MOUSE2
		if (creditsBuffer)
			FS_FreeFile (creditsBuffer);
		UI_PopMenu ();
		sound = menu_out_sound;
		break;
	}

	return sound;
}


void M_Menu_Credits_f ( void )
{
	int		n;
	int		count;
	char	*p;

	creditsBuffer = NULL;
	/*count = FS_LoadFile ("credits", &creditsBuffer);
	if (count != -1)
	{
		p = creditsBuffer;
		for (n = 0; n < 255; n++)
		{
			creditsIndex[n] = p;
			while (*p != '\r' && *p != '\n')
			{
				p++;
				if (--count == 0)
					break;
			}
			if (*p == '\r')
			{
				*p++ = 0;
				if (--count == 0)
					break;
			}
			*p++ = 0;
			if (--count == 0)
				break;
		}
		creditsIndex[++n] = 0;
		credits = creditsIndex;
	}
	else*/
	{	
		/*
		if (modType("xatrix"))			// xatrix
			credits = xatcredits;
		else if (modType("rogue"))		// ROGUE
			credits = roguecredits;
		else*/
			credits = idcredits;	
			
	}

	credits_start_time = cls.realtime;
	credits_start_line = 0; // Knightmare- allow credits to scroll past top of screen
	UI_PushMenu( M_Credits_MenuDraw, M_Credits_Key);
}
