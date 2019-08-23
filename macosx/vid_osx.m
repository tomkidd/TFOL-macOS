//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "vid_osx.c" - Main windowed and fullscreen graphics interface module. This module is used for both the software
//               and OpenGL rendering versions of the Quake refresh engine.
//
// Written by:	awe				            [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software	[http://www.idsoftware.com].
//
// Version History:
// v1.1.0: ¥ Added sorting of Video mode list.
// v1.0.8: ¥ Fixed an issue with CMD-TABing in fullscreen mode with ATI Radeon class gfx boards.
// v1.0.6: ¥ Added support for "vid_minrefresh" and "vid_maxrefresh".
//	       ¥ The variable for FSAA has changed to "gl_arb_multisample".
//         ¥ Removed underscore from symbolname parameter at call to "dlsym ()" [because of new "dlopen.c"].
// v1.0.5: ¥ Added support for new variables [gl_anisotropic, gl_fsaa and gl_truform].
// v1.0.3: ¥ Renderer specific vars are now archived here additionally, so that they don't get lost...
// v1.0.2: ¥ Added CMD-TABing in fullscreen mode.
// v1.0.1: ¥ Resolution list is now created dynamically.
// v1.0.0: ¥ Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#include <AppKit/AppKit.h>
#include <sys/param.h>
#include <unistd.h>
#include <dlfcn.h>

#include "client.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Macros

// We could iterate through active displays and capture them each, to avoid the CGReleaseAllDisplays() bug,
// but this would result in awfully switches between renderer selections, since we would have to clean-up the
// captured device list each time...

#ifdef CAPTURE_ALL_DISPLAYS

#define VID_FADE_ALL_SCREENS	YES
#define VID_CAPTURE_DISPLAYS()	CGCaptureAllDisplays ()
#define VID_RELEASE_DISPLAYS()	CGReleaseAllDisplays ()

#else

#define VID_FADE_ALL_SCREENS	NO
#define VID_CAPTURE_DISPLAYS()	CGDisplayCapture (kCGDirectMainDisplay)
#define VID_RELEASE_DISPLAYS()	CGDisplayRelease (kCGDirectMainDisplay)

#endif /* CAPTURE_ALL_DISPLAYS */

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Defines

#define	VID_MAX_PRINT_MSG	8192	// was 4096
#define VID_MAX_REF_NAME	256
#define VID_MAX_DISPLAYS	100
#define	VID_FADE_DURATION	1.0f

#ifdef VID_DO_NOT_UNLOAD_MODULES

// Required because it is currently not possible to unmap images conatining obj-c data.
// To keep this workaround simple, we will store base addresses of modules inside an array.

#define VID_MAX_MODULES		10

#endif /* VID_DO_NOT_UNLOAD_MODULES */

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Typedefs

typedef struct vidmode_s		{
                                    int        	width;
									int			height;
                                    float		refresh;
                                } vidmode_t;

typedef struct vidgamma_s		{
                                    CGDirectDisplayID	displayID;
                                    CGGammaValue	component[9];
                                } vidgamma_t;

typedef struct ref_lib_store_s	{
                                    void		*library;
                                    char		name[MAXPATHLEN];
                                } ref_lib_store_t;

#pragma mark -
                                
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

extern	cvar_t *		sys_windowed_mouse;

viddef_t				viddef;							// global video state

//refexport_t				re;							// function wrapper to the current refresh bundle.
//void					*reflib_library		= NULL;		// Handle to refresh bundle.
qboolean				kmgl_active			= false;	// Knightmare renamed

cvar_t					*vid_gamma			= NULL;		// Video gamma value.
cvar_t					*vid_ref			= NULL;		// Name of refresh bundle loaded.
cvar_t					*vid_xpos			= NULL;		// X coordinate of window position.
cvar_t					*vid_ypos			= NULL;		// Y coordinate of window position.
cvar_t					*vid_fullscreen		= NULL;		// Video fullscreen.
cvar_t					*vid_minrefresh		= NULL;		// Video min. refresh rate.
cvar_t					*vid_maxrefresh		= NULL;		// Video max. refresh rate [-1 = infinite].
cvar_t					*r_customwidth		= NULL;		// Knightmare added: custom video mode
cvar_t					*r_customheight		= NULL;		// Knightmare added: custom video mode
cvar_t					*r_customrefresh	= NULL;		// Knightmare added: custom video mode

static vidmode_t *		gVIDModes			= NULL;
static vidgamma_t *		gVIDOriginalGamma	= NULL;
static UInt16			gVIDModeCount		= 0;
static CGDisplayCount	gVIDGammaCount		= 0;

#ifdef VID_DO_NOT_UNLOAD_MODULES

static ref_lib_store_t	gVIDModuleList[VID_MAX_MODULES];

#endif /* VID_DO_NOT_UNLOAD_MODULES */

extern BOOL								gSysDedicated;

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

extern void	IN_ShowCursor (BOOL theState);
//extern void	Sys_Sleep (int msec);

void 		VID_Printf (int thePrintLevel, char *theFormat, ...);
void 		VID_Error (int theErrorLevel, char *theFormat, ...);
void 		VID_NewWindow (int theWidth, int theHeight);
qboolean 	VID_GetModeInfo (int *theWidth, int *theHeight, int theMode);
void		VID_Init (void);
qboolean 	VID_LoadRefresh (char *theName);
void		VID_FreeReflib (void);
void		VID_SetPaused (BOOL theState);
void		VID_CheckChanges (void);
void		VID_Restart_f (void);

static void	VID_AddModeToList (UInt16 theWidth, UInt16 theHeight, float theRefresh);
static void	VID_GetDisplayModes (void);
static BOOL	VID_FadeGammaInit (BOOL theFadeOnAllDisplays);
static void	VID_FadeGammaOut (BOOL theFadeOnAllDisplays, float theDuration);
static void	VID_FadeGammaIn (BOOL theFadeOnAllDisplays, float theDuration);
static int	VID_SortDisplayModesCbk(id pMode1, id pMode2, void* pContext);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void VID_Printf (int thePrintLevel, char *theFormat, ...)
{
    va_list		myArgPtr;
    char		myMessage[VID_MAX_PRINT_MSG];

    // formatted output conversion:
    va_start (myArgPtr, theFormat);
    vsnprintf (myMessage, VID_MAX_PRINT_MSG, theFormat, myArgPtr);
    va_end (myArgPtr);

    // print according to the print level:
    if (thePrintLevel == PRINT_ALL)
    {
        Com_Printf ("%s", myMessage);
    }
    else
    {
        Com_DPrintf ("%s", myMessage);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void VID_Error (int theErrorLevel, char *theFormat, ...)
{
    va_list		myArgPtr;
    char		myMessage[VID_MAX_PRINT_MSG];

    // formatted output conversion:
    va_start (myArgPtr, theFormat);
    vsnprintf (myMessage, VID_MAX_PRINT_MSG, theFormat, myArgPtr);
    va_end (myArgPtr);

    // submitt the error string:
    Com_Error (theErrorLevel, "%s", myMessage);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void VID_NewWindow (int theWidth, int theHeight)
{
    viddef.width	= theWidth;
    viddef.height	= theHeight;

	cl.force_refdef = true;	// Knightmare added, can't use a paused refdef
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

qboolean VID_GetModeInfo (int *theWidth, int *theHeight, int theMode)
{
	float	theRefresh;

	if (theMode == -1) // custom mode
	{	
		theRefresh = r_customrefresh->value;
		*theWidth  = r_customwidth->value;
		*theHeight = r_customheight->value;

		// check if our refresh rate is outside the range of "vid_minrefresh" and "vid_maxrefresh":
		if ((theRefresh < vid_minrefresh->value) || (vid_maxrefresh->value > 0 && theRefresh > vid_maxrefresh->value))
			Cvar_SetValue ("vid_refreshrate", -1.0f);
		else
			Cvar_SetValue ("vid_refreshrate", theRefresh);

		return (true);
	}
    
    
    //bc hardcode the resolutions.

    switch (theMode)
    {
        case 0:
            *theWidth = 640;
            *theHeight = 480;
            break;
        case 1:
            *theWidth = 800;
            *theHeight = 600;
            break;
        case 2:
            *theWidth = 856;
            *theHeight = 480;
            break;
        case 3:
            *theWidth = 960;
            *theHeight = 720;
            break;
        case 4:
            *theWidth = 1024;
            *theHeight = 480;
            break;
        case 5:
            *theWidth = 1024;
            *theHeight = 768;
            break;
        case 6:
            *theWidth = 1152;
            *theHeight = 864;
            break;
        case 7:
            *theWidth = 1280;
            *theHeight = 720;
            break;
        case 8:
            *theWidth = 1280;
            *theHeight = 768;
            break;
        case 9:
            *theWidth = 1280;
            *theHeight = 800;
            break;
        case 10:
            *theWidth = 1280;
            *theHeight = 960;
            break;
        case 11:
            *theWidth = 1280;
            *theHeight = 1024;
            break;
        case 12:
            *theWidth = 1360;
            *theHeight = 768;
            break;
        case 13:
            *theWidth = 1366;
            *theHeight = 768;
            break;
        case 14:
            *theWidth = 1400;
            *theHeight = 1050;
            break;
        case 15:
            *theWidth = 1440;
            *theHeight = 900;
            break;
        case 16:
            *theWidth = 1600;
            *theHeight = 900;
            break;
        case 17:
            *theWidth = 1600;
            *theHeight = 1200;
            break;
        case 18:
            *theWidth = 1680;
            *theHeight = 1050;
            break;
        case 19:
            *theWidth = 1920;
            *theHeight = 1080;
            break;
        case 20:
            *theWidth = 1920;
            *theHeight = 1200;
            break;
        case 21:
            *theWidth = 1920;
            *theHeight = 1440;
            break;
        case 22:
            *theWidth = 2048;
            *theHeight = 1536;
            break;
        case 23:
            *theWidth = 2560;
            *theHeight = 1440;
            break;
        case 24:
            *theWidth = 3200;
            *theHeight = 1080;
            break;
        case 25:
            *theWidth = 3840;
            *theHeight = 1080;
            break;
        default:
            *theWidth = 1024;
            *theHeight = 768;
            break;
    }
    

    
    
    
    Cvar_SetValue( "vid_refreshrate", 60 );
    
    /*
    // just return the current video size, false if the mode is not available:
    if (theMode < 0 || theMode >= gVIDModeCount)
    {
        *theWidth  = gVIDModes[0].width;
        *theHeight = gVIDModes[0].height;
		
        Cvar_SetValue ("vid_refreshrate", gVIDModes[0].refresh);
        
        return (false);
    }

    *theWidth  = gVIDModes[theMode].width;
    *theHeight = gVIDModes[theMode].height;
     
	
    Cvar_SetValue ("vid_refreshrate", gVIDModes[theMode].refresh);
    */
    return (true);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_Init (void)
{
#ifdef VID_DO_NOT_UNLOAD_MODULES

    UInt8 		i;

    for (i = 0; i < VID_MAX_MODULES; i++)
    {
        gVIDModuleList[i].library = NULL;
    }
    
#endif /* VID_DO_NOT_UNLOAD_MODULES */

    vid_ref 	    = Cvar_Get ("vid_ref",			"gl",	CVAR_ARCHIVE);	// Knightmare changed, was soft
    vid_xpos 	    = Cvar_Get ("vid_xpos",			"0",    CVAR_ARCHIVE);
    vid_ypos 	    = Cvar_Get ("vid_ypos",			"0",	CVAR_ARCHIVE);
    vid_fullscreen  = Cvar_Get ("vid_fullscreen",	"0",    CVAR_ARCHIVE);
    vid_gamma 	    = Cvar_Get ("vid_gamma",		"1",    CVAR_ARCHIVE);
    vid_minrefresh  = Cvar_Get ("vid_minrefresh",	"0",    CVAR_ARCHIVE);
    vid_maxrefresh  = Cvar_Get ("vid_maxrefresh",	"-1",	CVAR_ARCHIVE);
	r_customwidth	= Cvar_Get ("r_customwidth",	"1600", CVAR_ARCHIVE);
	r_customheight	= Cvar_Get ("r_customheight",	"1024", CVAR_ARCHIVE);
	r_customrefresh	= Cvar_Get ("r_customrefresh",	"-1",	CVAR_ARCHIVE);
/*
    // required so that they are remembered, even if the approriate renderer is not used:
	Cvar_Get ("sw_allow_modex",  	          "1",							CVAR_ARCHIVE);
	Cvar_Get ("sw_stipplealpha",	          "0",							CVAR_ARCHIVE);
	Cvar_Get ("sw_mode", 	 	              "0",							CVAR_ARCHIVE);
	Cvar_Get ("hand", 		 	              "0",							CVAR_USERINFO | CVAR_ARCHIVE);
	Cvar_Get ("gl_particle_min_size",         "2",							CVAR_ARCHIVE);
	Cvar_Get ("gl_particle_max_size",         "40",							CVAR_ARCHIVE);
	Cvar_Get ("gl_particle_size", 	          "40",							CVAR_ARCHIVE);
	Cvar_Get ("gl_particle_att_a", 	          "0.01",						CVAR_ARCHIVE);
	Cvar_Get ("gl_particle_att_b", 	          "0.0",						CVAR_ARCHIVE);
	Cvar_Get ("gl_particle_att_c", 	          "0.01",						CVAR_ARCHIVE);
	Cvar_Get ("gl_modulate", 		          "1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_mode", 		              "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_shadows", 		          "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_finish",		              "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_driver",                    "opengl32",					CVAR_ARCHIVE);
	Cvar_Get ("gl_texturemode",               "GL_LINEAR_MIPMAP_NEAREST",	CVAR_ARCHIVE);
	Cvar_Get ("gl_texturealphamode",          "default",					CVAR_ARCHIVE);
	Cvar_Get ("gl_texturesolidmode",          "default",					CVAR_ARCHIVE);
	Cvar_Get ("gl_vertex_arrays", 	          "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_ext_swapinterval", 	      "1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_ext_palettedtexture",       "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_ext_multitexture", 	      "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_ext_pointparameters",       "1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_ext_compiled_vertex_array", "1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_swapinterval",		      "1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_3dlabs_broken", 	          "1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_force16bit",   	          "0",							CVAR_ARCHIVE);

	Cvar_Get ("gl_anisotropic",   	          "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_arb_multisample", 	      "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_truform", 	  	          "-1",							CVAR_ARCHIVE);
	Cvar_Get ("gl_overbright_gamma",	      "0",							CVAR_ARCHIVE);
	Cvar_Get ("gl_arb_multitexture", 	      "0",							CVAR_ARCHIVE);
*/               
    if (sys_windowed_mouse == NULL)
    {
        sys_windowed_mouse = Cvar_Get( "sys_windowed_mouse", "1", CVAR_ARCHIVE );
    }
        
    // Add some console commands that we want to handle:
    Cmd_AddCommand ("vid_restart", VID_Restart_f);

    // Build display mode list:
    VID_GetDisplayModes ();

    // Hide the cursor:
    //if (vid_fullscreen->value != 0.0f || sys_windowed_mouse->value != 0.0f)
	if (vid_fullscreen->value != 0.0f || !cls.consoleActive)	// Knightmare changed, use mouse unless windowed and console is down
	{
        IN_ShowCursor (NO);
    }

    // Capture the screen(s):
    if (vid_fullscreen->value != 0.0f)
    {
        VID_FadeGammaOut (VID_FADE_ALL_SCREENS, VID_FADE_DURATION);
        VID_CAPTURE_DISPLAYS ();
        VID_FadeGammaIn (VID_FADE_ALL_SCREENS, 0.0f);
    }
    
    // Start the graphics mode and load refresh DLL:
    VID_CheckChanges();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_Shutdown (void)
{
    // shutdown the ref library:
    if (kmgl_active)
    {
        R_Shutdown ();
        VID_FreeReflib ();
    }

	if (gSysDedicated)	// Knightmare- do nothing here in dedicated mode!
		return;
	
    // release the screen(s):
    if (vid_fullscreen->value != 0.0f)
    {
        VID_FadeGammaOut (VID_FADE_ALL_SCREENS, 0.0f);
        if (CGDisplayIsCaptured (kCGDirectMainDisplay) == true)
        {
            VID_RELEASE_DISPLAYS ();
        }
        VID_FadeGammaIn (VID_FADE_ALL_SCREENS, VID_FADE_DURATION);
    }

    // free the mode list:
    if (gVIDModes != NULL)
    {
        free (gVIDModes);
        gVIDModes = NULL;
        gVIDModeCount = 0;
    }

    // show the cursor:
    IN_ShowCursor (YES);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------
#if 0	// Knightmare- removed this function, as the renderer is integrated
qboolean VID_LoadRefresh (char *theName)
{
	refimport_t		myRefImport;
	GetRefAPI_t		myGetRefAPIProc;
	NSBundle *		myAppBundle = NULL;
	char *			myBundlePath = NULL;
	char *			myCurrentPath[MAXPATHLEN];
	char *			myFileName[MAXPATHLEN];

	// get current game directory:
	getcwd (myCurrentPath, sizeof (myCurrentPath));

	// get the plugin dir of the application:
	myAppBundle = [NSBundle mainBundle];

	if (myAppBundle == NULL)
	{
		Sys_Error ("Error while loading the renderer plug-in (invalid application bundle)!\n");
	}

	myBundlePath = (char *) [[myAppBundle builtInPlugInsPath] fileSystemRepresentation];
   
	if (myBundlePath == NULL)
	{
		Sys_Error ("Error while loading the renderer plug-in (invalid plug-in path)!\n");
	}
    
	chdir (myBundlePath);

	[myAppBundle release];
    
	// prepare the bundle name:
	snprintf (myFileName, MAXPATHLEN, "%s.q2plug/Contents/MacOS/%s", theName, theName);

	if (reflib_active == true)
	{
		R_Shutdown ();
		VID_FreeReflib ();
		reflib_active = false;
	}

	Com_Printf("------- Loading %s -------\n", theName);

#ifdef VID_DO_NOT_UNLOAD_MODULES

    {
        UInt8 		i;

        for (i = 0; i < VID_MAX_MODULES; i++)
        {
            if (gVIDModuleList[i].library != NULL)
            {
                if (strcmp (gVIDModuleList[i].name, theName) == 0)
                {
                    reflib_library = gVIDModuleList[i].library;
                    break;
                }
            }
        }
    }

    if (!reflib_library)

#endif /* VID_DO_NOT_UNLOAD_MODULES */

    reflib_library = dlopen (myFileName, RTLD_LAZY | RTLD_GLOBAL);

    // return to the game directory:
    chdir (myCurrentPath);

    if (reflib_library == NULL)
    {
        Com_Printf ("LoadLibrary(\"%s\") failed: %s\n", theName , dlerror());
        return (false);
    }

    Com_Printf ("LoadLibrary(\"%s\")\n", myFileName);

	if ((myGetRefAPIProc = (void *) dlsym (reflib_library, "GetRefAPI")) == NULL)
    {
        Com_Error (ERR_FATAL, "dlsym failed on %s", theName);
    }

#ifdef VID_DO_NOT_UNLOAD_MODULES

    {
        UInt8 		i;

        for (i = 0; i < VID_MAX_MODULES; i++)
        {
            if (strcmp (gVIDModuleList[i].name, theName) == 0 || gVIDModuleList[i].library == NULL)
            {
                gVIDModuleList[i].library = reflib_library;
                strcpy (gVIDModuleList[i].name, theName);
                break;
            }
        }
        if (i == VID_MAX_MODULES)
        {
            Com_Error (ERR_FATAL, "Module load failed (no free slots)!");
        }
    }

#endif /* VID_DO_NOT_UNLOAD_MODULES */

	myRefImport.Cmd_AddCommand		= Cmd_AddCommand;
	myRefImport.Cmd_RemoveCommand	= Cmd_RemoveCommand;
	myRefImport.Cmd_Argc			= Cmd_Argc;
	myRefImport.Cmd_Argv			= Cmd_Argv;
	myRefImport.Cmd_ExecuteText		= Cbuf_ExecuteText;
	myRefImport.Con_Printf			= VID_Printf;
	myRefImport.Sys_Error			= VID_Error;
	myRefImport.FS_LoadFile			= FS_LoadFile;
	myRefImport.FS_FreeFile			= FS_FreeFile;
	myRefImport.FS_Gamedir			= FS_Gamedir;
	myRefImport.Cvar_Get			= Cvar_Get;
	myRefImport.Cvar_Set			= Cvar_Set;
	myRefImport.Cvar_SetValue		= Cvar_SetValue;
	myRefImport.Vid_GetModeInfo		= VID_GetModeInfo;
	myRefImport.Vid_MenuInit		= VID_MenuInit;
	myRefImport.Vid_NewWindow		= VID_NewWindow;

	re = myGetRefAPIProc (myRefImport);

	if (re.api_version != API_VERSION)
	{
		VID_FreeReflib ();
		Com_Error (ERR_FATAL, "%s has incompatible api_version!", theName);
	}

	if (R_Init (0, 0) == -1)
	{
		R_Shutdown ();
		VID_FreeReflib ();
		return (false);
	}

	Com_Printf ("------------------------------------\n");
	reflib_active = true;

	return (true);
}
#endif	// Knightmare removed
//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_FreeReflib (void)
{
#ifndef VID_DO_NOT_UNLOAD_MODULES
/*
    if (reflib_library != NULL)
    {
        dlclose (reflib_library);
    }
*/
#endif /* VID_DO_NOT_UNLOAD_MODULES */

//	memset (&re, 0, sizeof (re));
//	reflib_library = NULL;
	kmgl_active  = false;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_SetPaused (BOOL theState)
{
    if (vid_fullscreen->value != 0.0f)
    {
        static BOOL	myState = NO;

        if (theState != myState)
        {
			if (theState == YES)
			{
				// release the screen(s):
				VID_FadeGammaOut (VID_FADE_ALL_SCREENS, 0.0f);

				if (kmgl_active)
				{
					// Knightmare- shutting down and re-initializing the renderer
					// is a bad idea due to load times.  Just pause it instead.
					R_Shutdown ();
					VID_FreeReflib ();
				//	Cvar_SetValue ("paused", 1);
				}

				if (CGDisplayIsCaptured (kCGDirectMainDisplay) == true)
				{
					VID_RELEASE_DISPLAYS ();
				}

				VID_FadeGammaIn (VID_FADE_ALL_SCREENS, 0.0f);
			}
			else
			{
				// Capture the screen(s):
				VID_FadeGammaOut (VID_FADE_ALL_SCREENS, 0.0f);
				VID_CAPTURE_DISPLAYS ();
				VID_FadeGammaIn (VID_FADE_ALL_SCREENS, 0.0f);
				vid_ref->modified = true;
				VID_CheckChanges ();
			//	Cvar_SetValue ("paused", 0);	// Knightmare- unpause
			}
			myState = theState;
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

// Knightmare added
extern	decalpolys_t	*active_decals;
static qboolean	reclip_decals = false;
qboolean		vid_reloading; // flag to not unnecessarily drop console
// end Knightmare

void	VID_CheckChanges (void)
{
 	char		reason[128];
//	char		myName[VID_MAX_REF_NAME];
//	cvar_t *	mySWMode;

    if (vid_ref->modified)
    {
		cl.force_refdef = true;	// Knightmare added, can't use a paused refdef
		S_StopAllSounds ();

		// Knightmare added- unclip decals
		if (active_decals) {
			CL_UnclipDecals ();
			reclip_decals = true;
		}
    }

	vid_reloading = false;	// Knightmare added

    while (vid_ref->modified)
    {
        vid_ref->modified			= false;
        vid_fullscreen->modified	= true;
        cl.refresh_prepped			= false;
		if (cl.cinematictime > 0) // Knightmare added
			cls.disable_screen		= false;
		else
			cls.disable_screen		= true;
		vid_reloading = true;	// Knightmare added
		// end Knightmare

		//==========================
		// compacted code from VID_LoadRefresh
		//==========================
		if (kmgl_active == true)
		{
			R_Shutdown ();
			VID_FreeReflib ();
			kmgl_active = false;
		}

		Com_Printf( "\n------ Renderer Initialization ------\n");


		if ( !R_Init (0, 0, reason) )
		{
			R_Shutdown ();
			VID_FreeReflib ();
			Com_Error (ERR_FATAL, "Couldn't initialize OpenGL renderer!\n%s", reason);
		}

		Com_Printf ("------------------------------------\n");

		kmgl_active = true;
		//==========================

		/*
        snprintf (myName, VID_MAX_REF_NAME, "ref_%s", vid_ref->string);

        if (VID_LoadRefresh (myName) == false)
        {
            if (strcmp (vid_ref->string, "soft") == 0)
            {
                Com_Printf ("Refresh failed\n");
                mySWMode = Cvar_Get ("sw_mode", "0", 0);
				
                if (mySWMode->value != 0)
                {
                    Com_Printf ("Trying mode 0\n");
                    Cvar_SetValue ("sw_mode", 0);
                    if (VID_LoadRefresh (myName) == false)
                    {
                        Com_Error (ERR_FATAL, "Couldn't fall back to software refresh!");
                    }
                }
                else
                {
                    Com_Error (ERR_FATAL, "Couldn't fall back to software refresh!");
                }
            }

            Cvar_Set ("vid_ref", "soft");

            if (cls.key_dest != key_console)
            {
                Con_ToggleConsole_f ();
            }
        }
        cls.disable_screen = false;
		*/
    }

	// Knightmare- added to close loading screen
	if (cl.refresh_prepped && vid_reloading)
		cls.disable_screen = false;

	// Knightmare- re-clip decals
	if (cl.refresh_prepped && reclip_decals) {
		CL_ReclipDecals ();
		reclip_decals = false;
	}

 	vid_reloading = false;	// Knightmare added
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void VID_Restart_f (void)
{
    vid_ref->modified = true;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_AddModeToList (UInt16 theWidth, UInt16 theHeight, float theRefresh)
{
    UInt32	j;

    // check if the max refresh is smaller than the min refresh. If yes, set it to infinite:
    if (vid_maxrefresh->value > 0.0f && vid_maxrefresh->value < vid_minrefresh->value)
    {
        Com_Printf ("vid_maxrefresh is smaller than vid_minrefresh.\nSetting vid_maxrefresh to -1 [=infinite].\n");
        Cvar_SetValue ("vid_maxrefresh", -1.0f);
    }
    
    if (vid_minrefresh->value < 0.0f)
    {
        Com_Printf ("vid_minrefresh is smaller than zero.\nSetting vid_minrefresh to zero.\n");
        Cvar_SetValue ("vid_minrefresh", 0.0f);
    }
    
    // check if our refresh rate is inside the range of "vid_minrefresh" and "vid_maxrefresh":
    if ((theRefresh < vid_minrefresh->value) || (vid_maxrefresh->value > 0 && theRefresh > vid_maxrefresh->value))
    {
        return;
    }
    
    if (vid_minrefresh->value == 0.0f && vid_maxrefresh->value < 0.0f)
    {
        theRefresh = -1.0f;
    }
    
    // collect each resolution only once:
    for (j = 0; j < gVIDModeCount; j++)
    {
        if (gVIDModes[j].width == theWidth && gVIDModes[j].height == theHeight)
        {
            break;
        }
    }
    
    // insert the new mode in our mode list:
    if (j == gVIDModeCount)
    {
        gVIDModes[gVIDModeCount].width		= theWidth;
        gVIDModes[gVIDModeCount].height		= theHeight;
        gVIDModes[gVIDModeCount].refresh	= theRefresh;
        gVIDModeCount++;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	VID_SortDisplayModesCbk(id pMode1, id pMode2, void* pContext)
{
	// used to sort display modes by pixels/refresh

	UInt64	width1		= [[pMode1 objectForKey: (NSString *) kCGDisplayWidth] intValue];
	UInt64	height1		= [[pMode1 objectForKey: (NSString *) kCGDisplayHeight] intValue];
	UInt64	refresh1	= [[pMode1 objectForKey: (NSString *) kCGDisplayRefreshRate] intValue];

	UInt64	width2		= [[pMode2 objectForKey: (NSString *) kCGDisplayWidth] intValue];
	UInt64	height2		= [[pMode2 objectForKey: (NSString *) kCGDisplayHeight] intValue];
	UInt64	refresh2	= [[pMode2 objectForKey: (NSString *) kCGDisplayRefreshRate] intValue];
		
	UInt64	pixels1		= width1 * height1;
	UInt64	pixels2		= width2 * height2;
	int		result		= NSOrderedDescending;
	
	if ((pixels1 < pixels2) || (pixels1 == pixels2 && refresh1 < refresh2))
	{
		result = NSOrderedAscending;
	}

	return result;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_GetDisplayModes (void)
{
    NSArray *			myDisplayModes;
	NSMutableArray *	mySortedModes;
    float				myRate;
    UInt16				myModeCount = 0;
	UInt16				myWidth;
	UInt16				myHeight;
	UInt16				i;
    
    // get rid of the old display list, if there is any:
    if (gVIDModes != NULL)
    {
        free (gVIDModes);
        gVIDModes = NULL;
        gVIDModeCount = 0;
    }

    // retrieve a list with all display modes:
    myDisplayModes = [(NSArray *) CGDisplayAvailableModes (kCGDirectMainDisplay) retain];
    
	if (myDisplayModes == nil)
    {
        Sys_Error ("Unable to get list of available display modes.");
    }

	mySortedModes = [[NSMutableArray alloc] initWithArray: myDisplayModes];

	[mySortedModes sortUsingFunction: VID_SortDisplayModesCbk context: nil];
	
    myModeCount = [mySortedModes count];
    
	if (myModeCount == 0)
    {
        Sys_Error ("Unable to get list of available display modes.");
    }

    gVIDModes = malloc ((myModeCount + 1) * sizeof(vidmode_t) * 2);
	
    if (gVIDModes == NULL)
    {
        Sys_Error ("Out of memory!");
    }
    
    // scan for 2x2 modes first:
    for (i = 0; i < myModeCount; i++)
    {
        myWidth		= [[[mySortedModes objectAtIndex: i] objectForKey: (NSString *) kCGDisplayWidth] intValue];
        myHeight	= [[[mySortedModes objectAtIndex: i] objectForKey: (NSString *) kCGDisplayHeight] intValue];
        myRate		= [[[mySortedModes objectAtIndex: i] objectForKey: (NSString *) kCGDisplayRefreshRate] floatValue];
        
        if (myWidth < 640 || myHeight < 480)
        {
            continue;
        }
        
        myWidth = myWidth >> 1;
        myHeight = myHeight >> 1;
        
        if (myWidth < 640 || myHeight < 480)
        {
            VID_AddModeToList (myWidth, myHeight, myRate);            
        }
    }
    
    // scan for 1x1 modes next:
    for (i = 0; i < myModeCount; i++)
    {
        myWidth		= [[[mySortedModes objectAtIndex: i] objectForKey: (NSString *) kCGDisplayWidth] intValue];
        myHeight	= [[[mySortedModes objectAtIndex: i] objectForKey: (NSString *) kCGDisplayHeight] intValue];
        myRate		= [[[mySortedModes objectAtIndex: i] objectForKey: (NSString *) kCGDisplayRefreshRate] floatValue];
        
        if (myWidth < 640 || myHeight < 480)
        {
            continue;
        }

        VID_AddModeToList (myWidth, myHeight, myRate);
    }
    
    [myDisplayModes release];
	[mySortedModes release];
    
    if (gVIDModeCount == 0)
    {
        Sys_Error ("Unable to get list of available display modes.");
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

BOOL	VID_FadeGammaInit (BOOL theFadeOnAllDisplays)
{
    static BOOL			myFadeOnAllDisplays = NO;
    CGDirectDisplayID  	myDisplayList[VID_MAX_DISPLAYS];
    CGDisplayErr		myError;
    UInt32				i;

    // if init fails, no gamma fading will be used!    
    if (gVIDOriginalGamma != NULL)
    {
        // initialized, but did we change the number of displays?
        if (theFadeOnAllDisplays == myFadeOnAllDisplays)
        {
            return (YES);
        }
        free (gVIDOriginalGamma);
        gVIDOriginalGamma = NULL;
    }

    // get the list of displays:
    if (CGGetActiveDisplayList (VID_MAX_DISPLAYS, myDisplayList, &gVIDGammaCount) != CGDisplayNoErr)
    {
        return (NO);
    }
    
    if (gVIDGammaCount == 0)
    {
        return (NO);
    }
    
    if (theFadeOnAllDisplays == NO)
    {
        gVIDGammaCount = 1;
    }
    
    // get memory for our original gamma table(s):
    gVIDOriginalGamma = malloc (sizeof (vidgamma_t) * gVIDGammaCount);
    if (gVIDOriginalGamma == NULL)
    {
        return (NO);
    }
    
    // store the original gamma values within this table(s):
    for (i = 0; i < gVIDGammaCount; i++)
    {
        if (gVIDGammaCount == 1)
        {
            gVIDOriginalGamma[i].displayID = kCGDirectMainDisplay;
        }
        else
        {
            gVIDOriginalGamma[i].displayID = myDisplayList[i];
        }

        myError = CGGetDisplayTransferByFormula (gVIDOriginalGamma[i].displayID,
                                                 &gVIDOriginalGamma[i].component[0],
                                                 &gVIDOriginalGamma[i].component[1],
                                                 &gVIDOriginalGamma[i].component[2],
                                                 &gVIDOriginalGamma[i].component[3],
                                                 &gVIDOriginalGamma[i].component[4],
                                                 &gVIDOriginalGamma[i].component[5],
                                                 &gVIDOriginalGamma[i].component[6],
                                                 &gVIDOriginalGamma[i].component[7],
                                                 &gVIDOriginalGamma[i].component[8]);
        if (myError != CGDisplayNoErr)
        {
            free (gVIDOriginalGamma);
            gVIDOriginalGamma = NULL;
            return (NO);
        }
    }
    myFadeOnAllDisplays = theFadeOnAllDisplays;

    return (YES);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_FadeGammaOut (BOOL theFadeOnAllDisplays, float theDuration)
{
    vidgamma_t		myCurGamma;
    float			myStartTime = 0.0f;
	float			myCurScale = 0.0f;
    UInt32			i;
	UInt32			j;

    // check if initialized:
    if (VID_FadeGammaInit (theFadeOnAllDisplays) == NO)
    {
        return;
    }
    
    // get the time of the fade start:
    myStartTime = Sys_Milliseconds ();
    theDuration *= 1000.0f;
    
    // fade for the choosen duration:
    while (1)
    {
        // calculate the current scale and clamp it:
        if (theDuration > 0.0f)
        {
            myCurScale = 1.0f - (Sys_Milliseconds () - myStartTime) / theDuration;
            if (myCurScale < 0.0f)
            {
                myCurScale = 0.0f;
            }
        }

        // fade the gamma for each display:        
        for (i = 0; i < gVIDGammaCount; i++)
        {
            // calculate the current intensity for each color component:
            for (j = 1; j < 9; j += 3)
            {
                myCurGamma.component[j] = myCurScale * gVIDOriginalGamma[i].component[j];
            }

            // set the current gamma:
            CGSetDisplayTransferByFormula (gVIDOriginalGamma[i].displayID,
                                           gVIDOriginalGamma[i].component[0],
                                           myCurGamma.component[1],
                                           gVIDOriginalGamma[i].component[2],
                                           gVIDOriginalGamma[i].component[3],
                                           myCurGamma.component[4],
                                           gVIDOriginalGamma[i].component[5],
                                           gVIDOriginalGamma[i].component[6],
                                           myCurGamma.component[7],
                                           gVIDOriginalGamma[i].component[8]);
        }
        
        // are we finished?
        if(myCurScale <= 0.0f)
        {
            break;
        } 
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	VID_FadeGammaIn (BOOL theFadeOnAllDisplays, float theDuration)
{
    vidgamma_t		myCurGamma;
    float			myStartTime = 0.0f;
	float			myCurScale = 1.0f;
    UInt32			i;
	UInt32			j;

    // check if initialized:
    if (gVIDOriginalGamma == NULL)
    {
        return;
    }
    
    // get the time of the fade start:
    myStartTime = Sys_Milliseconds ();
    theDuration *= 1000.0f;
    
    // fade for the choosen duration:
    while (1)
    {
        // calculate the current scale and clamp it:
        if (theDuration > 0.0f)
        {
            myCurScale = (Sys_Milliseconds () - myStartTime) / theDuration;
            if (myCurScale > 1.0f)
            {
                myCurScale = 1.0f;
            }
        }

        // fade the gamma for each display:
        for (i = 0; i < gVIDGammaCount; i++)
        {
            // calculate the current intensity for each color component:
            for (j = 1; j < 9; j += 3)
            {
                myCurGamma.component[j] = myCurScale * gVIDOriginalGamma[i].component[j];
            }

            // set the current gamma:
            CGSetDisplayTransferByFormula (gVIDOriginalGamma[i].displayID,
                                           gVIDOriginalGamma[i].component[0],
                                           myCurGamma.component[1],
                                           gVIDOriginalGamma[i].component[2],
                                           gVIDOriginalGamma[i].component[3],
                                           myCurGamma.component[4],
                                           gVIDOriginalGamma[i].component[5],
                                           gVIDOriginalGamma[i].component[6],
                                           myCurGamma.component[7],
                                           gVIDOriginalGamma[i].component[8]);
        }
        
        // are we finished?
        if(myCurScale >= 1.0f)
        {
            break;
        } 
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------
