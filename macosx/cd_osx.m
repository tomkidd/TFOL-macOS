//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "cd_osx.m" - MacOS X audio CD driver.
//
// Written by:	awe			               	[mailto:awe@fruitz-of-dojo.de].
//	            �2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake II� is copyrighted by id software	[http://www.idsoftware.com].
//
// Version History:
// v1.0.8: Rewritten. Uses now QuickTime for playback. Added support for MP3 and MP4 [AAC] playback.
// v1.0.3: Fixed an issue with requesting a track number greater than the max number.
// v1.0.1: Added "cdda" as extension for detection of audio-tracks [required by MacOS X v10.1 or later]
// v1.0.0: Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>
#import <CoreAudio/AudioHardware.h>
//#import <QuickTime/QuickTime.h>
#import <sys/mount.h>
#import <pthread.h>

#import "client.h"
#import "cd_osx.h"
#import "sys_osx.h"
#import "Quake2.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

cvar_t *					cd_volume;

static UInt16				gCDTrackCount;
static UInt16				gCurCDTrack;
static NSMutableArray *		gCDTrackList;
static char					gCDDevice[MAX_OSPATH];
static BOOL					gCDLoop;
static BOOL					gCDNextTrack;
//static Movie                gCDController = NULL;

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

BOOL				CDAudio_GetTrackList (void);
void				CDAudio_Enable (BOOL theState);

static	void		CDAudio_Error (cderror_t theErrorNumber);
//static    SInt32        CDAudio_StripVideoTracks (Movie theMovie);
static	void		CDAudio_SafePath (const char *thePath);
static	void		CDAudio_AddTracks2List (NSString *theMountPath, NSArray *theExtensions);
static 	void 		CD_f (void);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Error (cderror_t theErrorNumber)
{
#ifdef SYS_CD_USE_MP3	
    if ([[NSApp delegate] mediaFolder] == NULL)
#endif	// SYS_CD_USE_MP3
    {
        Com_Printf ("Audio-CD driver: ");
    }
#ifdef SYS_CD_USE_MP3
    else
    {
        Com_Printf ("MP3/MP4 driver: ");
    }
#endif	// SYS_CD_USE_MP3
	
    switch (theErrorNumber)
    {
        case CDERR_ALLOC_TRACK:
            Com_Printf ("Failed to allocate track!\n");
            break;
        case CDERR_MOVIE_DATA:
            Com_Printf ("Failed to retrieve track data!\n");
            break;
        case CDERR_AUDIO_DATA:
            Com_Printf ("File without audio track!\n");
            break;
        case CDERR_QUICKTIME_ERROR:
            Com_Printf ("QuickTime error!\n");
            break;
        case CDERR_THREAD_ERROR:
            Com_Printf ("Failed to initialize thread!\n");
            break;
        case CDERR_NO_MEDIA_FOUND:
            Com_Printf ("No Audio-CD found.\n");
            break;
        case CDERR_MEDIA_TRACK:
            Com_Printf ("Failed to retrieve media track!\n");
            break;
        case CDERR_MEDIA_TRACK_CONTROLLER:
            Com_Printf ("Failed to retrieve track controller!\n");
            break;
        case CDERR_EJECT:
            Com_Printf ("Can\'t eject Audio-CD!\n");
            break;
        case CDERR_NO_FILES_FOUND:
#ifdef SYS_CD_USE_MP3
            if ([[NSApp delegate] mediaFolder] == NULL)
#endif	// SYS_CD_USE_MP3
            {
                Com_Printf ("No audio tracks found.\n");
            }
#ifdef SYS_CD_USE_MP3
            else
            {
                Com_Printf ("No files found with the extension \'.mp3\', \'.mp4\' or \'.m4a\'!\n");
            }
#endif	// SYS_CD_USE_MP3
            break;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

//SInt32    CDAudio_StripVideoTracks (Movie theMovie)
//{
//    SInt64    i = GetMovieTrackCount (theMovie);
//
//    for (; i >= 1; i--)
//    {
//        Track        myCurTrack = GetMovieIndTrack (theMovie, i);
//         OSType     myMediaType;
//
//        GetMediaHandlerDescription (GetTrackMedia (myCurTrack), &myMediaType, NULL, NULL);
//
//        if (myMediaType != SoundMediaType && myMediaType != MusicMediaType)
//        {
//            DisposeMovieTrack (myCurTrack);
//        }
//    }
//
//    return (GetMovieTrackCount (theMovie));
//}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_AddTracks2List (NSString *theMountPath, NSArray *theExtensions)
{
    NSFileManager *	myFileManager = [NSFileManager defaultManager];
    
    if (myFileManager != NULL)
    {
        NSDirectoryEnumerator *	myDirEnum = [myFileManager enumeratorAtPath: theMountPath];

        if (myDirEnum != NULL)
        {
            NSString *	myFilePath;
			SInt32		myExtensionCount = [theExtensions count];
            
            // get all audio tracks:
            while ((myFilePath = [myDirEnum nextObject]) && [[NSApp delegate] abortMediaScan] == NO)
            {
				SInt32		myIndex = 0;
				
                for (; myIndex < myExtensionCount; myIndex++)
                {
                    if ([[myFilePath pathExtension] isEqualToString: [theExtensions objectAtIndex: myIndex]])
                    {
                        NSString *	myFullPath	= [theMountPath stringByAppendingPathComponent: myFilePath];
                        NSURL *		myMoviePath	= [NSURL fileURLWithPath: myFullPath];
                        NSMovie	*	myMovie		= [[NSMovie alloc] initWithURL: myMoviePath byReference: YES];
//                        Movie        myQTMovie    = [myMovie QTMovie];
//
//                        if (myQTMovie != nil)
//                        {
//                            // add only movies with audiotacks and use only the audio track:
//                            if (CDAudio_StripVideoTracks (myQTMovie) > 0)
//                            {
//                                [gCDTrackList addObject: myMovie];
//                            }
//                            else
//                            {
//                                CDAudio_Error (CDERR_AUDIO_DATA);
//                            }
//                        }
//                        else
//                        {
//                            CDAudio_Error (CDERR_MOVIE_DATA);
//                        }
                    }
                }
            }
        }
    }
	
    gCDTrackCount = [gCDTrackList count];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_SafePath (const char *thePath)
{
    SInt32	myStrLength = 0;

    if (thePath != nil)
    {
        SInt32		i;
        
        myStrLength = strlen (thePath);
        
		if (myStrLength > MAX_OSPATH - 1)
        {
            myStrLength = MAX_OSPATH - 1;
        }
        
		for (i = 0; i < myStrLength; i++)
        {
            gCDDevice[i] = thePath[i];
        }
    }
	
    gCDDevice[myStrLength] = 0x00;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

BOOL	CDAudio_GetTrackList (void)
{
    NSAutoreleasePool *	myPool;
    
    // release previously allocated memory:
    CDAudio_Shutdown ();
    
    // get memory for the new tracklisting:
    gCDTrackList	= [[NSMutableArray alloc] init];
    myPool			= [[NSAutoreleasePool alloc] init];
    gCDTrackCount	= 0;

#ifdef SYS_CD_USE_MP3
    // Get the current MP3 listing or retrieve the TOC of the AudioCD:
    if ([[NSApp delegate] mediaFolder] != NULL)
    {
        NSString	*myMediaFolder = [[NSApp delegate] mediaFolder];

        CDAudio_SafePath ([myMediaFolder fileSystemRepresentation]);
        Com_Printf ("Scanning for audio tracks. Be patient!\n");
        CDAudio_AddTracks2List (myMediaFolder, [NSArray arrayWithObjects: @"mp3", @"mp4", @"m4a", NULL]);
    }
    else
#endif	// SYS_CD_USE_MP3
    {
        NSString *		myMountPath;
        struct statfs *	myMountList;
        UInt32			myMountCount;

        // get number of mounted devices:
        myMountCount = getmntinfo (&myMountList, MNT_NOWAIT);
        
        // zero devices? return.
        if (myMountCount <= 0)
        {
            [gCDTrackList release];
            
			gCDTrackList	= NULL;
            gCDTrackCount	= 0;
            
			CDAudio_Error (CDERR_NO_MEDIA_FOUND);
            return (0);
        }
        
        while (myMountCount--)
        {
            // is the device read only?
            if ((myMountList[myMountCount].f_flags & MNT_RDONLY) != MNT_RDONLY) continue;
            
            // is the device local?
            if ((myMountList[myMountCount].f_flags & MNT_LOCAL) != MNT_LOCAL) continue;
            
            // is the device "cdda"?
            if (strcmp (myMountList[myMountCount].f_fstypename, "cddafs")) continue;
            
            // is the device a directory?
            if (strrchr (myMountList[myMountCount].f_mntonname, '/') == NULL) continue;
            
            // we have found a Audio-CD!
            Com_Printf ("Found Audio-CD at mount entry: \"%s\".\n", myMountList[myMountCount].f_mntonname);
            
            // preserve the device name:
            CDAudio_SafePath (myMountList[myMountCount].f_mntonname);
            myMountPath = [NSString stringWithCString: myMountList[myMountCount].f_mntonname];
    
            Con_Print ("Scanning for audio tracks. Be patient!\n");
            CDAudio_AddTracks2List (myMountPath, [NSArray arrayWithObjects: @"aiff", @"cdda", NULL]);
            
            break;
        }
    }
    
    // release the pool:
    [myPool release];
    
    // just security:
    if (![gCDTrackList count])
    {
        [gCDTrackList release];
        
		gCDTrackList	= nil;
        gCDTrackCount	= 0;
        
		CDAudio_Error (CDERR_NO_FILES_FOUND);
        return (0);
    }
    
    return (1);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Play (int theTrack, qboolean theLoop)
{
    gCDNextTrack = NO;
    
    if (gCDTrackList != NULL && gCDTrackCount != 0)
    {
        NSMovie	*	myMovie;
        
        // check for mismatching CD track number:
        if (theTrack > gCDTrackCount || theTrack <= 0)
        {
            theTrack = 1;
        }
        gCurCDTrack = 0;
        
        if (gCDController != NULL && IsMovieDone (gCDController) == NO)
        {
            StopMovie(gCDController);
            gCDController = NULL;
        }
        
        myMovie = [gCDTrackList objectAtIndex: theTrack - 1];
        
        if (myMovie != NULL)
        {
            gCDController = [myMovie QTMovie];
            
            if (gCDController != NULL)
            {
                gCurCDTrack	= theTrack;
                gCDLoop		= theLoop;
				
                GoToBeginningOfMovie (gCDController);
                SetMovieActive (gCDController, YES);
                StartMovie (gCDController);
				
				if (GetMoviesError () != noErr)
				{
                    CDAudio_Error (CDERR_QUICKTIME_ERROR);
				}
            }
            else
            {
                CDAudio_Error (CDERR_MEDIA_TRACK);
            }
        }
        else
        {
            CDAudio_Error (CDERR_MEDIA_TRACK_CONTROLLER);
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Stop (void)
{
    // just stop the audio IO:
    if (gCDController != NULL && IsMovieDone (gCDController) == NO)
    {
        StopMovie (gCDController);
        GoToBeginningOfMovie (gCDController);
        SetMovieActive (gCDController, NO);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Pause (void)
{
    if (gCDController != NULL && GetMovieActive (gCDController) == YES && IsMovieDone (gCDController) == NO)
    {
        StopMovie (gCDController);
        SetMovieActive (gCDController, NO);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Resume (void)
{
    if (gCDController != NULL && GetMovieActive (gCDController) == NO && IsMovieDone (gCDController) == NO)
    {
        SetMovieActive (gCDController, YES);
        StartMovie (gCDController);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Update (void)
{
    // update volume settings:
    if (gCDController != NULL)
    {
        SetMovieVolume (gCDController, kFullVolume * cd_volume->value);

        if (GetMovieActive (gCDController) == YES)
        {
            if (IsMovieDone (gCDController) == NO)
            {
                MoviesTask (gCDController, 0);
            }
            else
            {
                if (gCDLoop == YES)
                {
                    GoToBeginningOfMovie (gCDController);
                    StartMovie (gCDController);
                }
                else
                {
                    gCurCDTrack++;
                    CDAudio_Play (gCurCDTrack, NO);
                }
            }
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Enable (BOOL theState)
{
    static BOOL	myCDIsEnabled = YES;
    
    if (myCDIsEnabled != theState)
    {
        static BOOL	myCDWasPlaying = NO;
        
        if (theState == NO)
        {
            if (gCDController != NULL && GetMovieActive (gCDController) == YES && IsMovieDone (gCDController) == NO)
            {
                CDAudio_Pause ();
                myCDWasPlaying = YES;
            }
            else
            {
                myCDWasPlaying = NO;
            }
        }
        else
        {
            if (myCDWasPlaying == YES)
            {
                CDAudio_Resume ();
            }
        }
		
        myCDIsEnabled = theState;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	CDAudio_Init (void)
{
    // register the volume var:
    cd_volume = Cvar_Get ("cd_volume", "1", CVAR_ARCHIVE);

#ifdef SYS_CD_USE_MP3	
    // add "cd" and "mp3" console command:
    if ([[NSApp delegate] mediaFolder] != NULL)
    {
        Cmd_AddCommand ("mp3", CD_f);
        Cmd_AddCommand ("mp4", CD_f);
    }
#endif	// SYS_CD_USE_MP3
    Cmd_AddCommand ("cd", CD_f);
    
    gCurCDTrack = 0;
    
    if (gCDTrackList != nil)
    {
#ifdef SYS_CD_USE_MP3
        if ([[NSApp delegate] mediaFolder] == nil)
#endif	// SYS_CD_USE_MP3
        {
            Con_Print ("QuickTime CD driver initialized...\n");
        }
#ifdef SYS_CD_USE_MP3
        else
        {
            Con_Print ("QuickTime MP3/MP4 driver initialized...\n");
        }
#endif	// SYS_CD_USE_MP3
        return (1);
    }
	
#ifdef SYS_CD_USE_MP3    
    if ([[NSApp delegate] mediaFolder] == nil)
#endif	// SYS_CD_USE_MP3
    {
        Con_Print ("QuickTime CD driver failed.\n");
    }
#ifdef SYS_CD_USE_MP3
    else
    {
        Con_Print ("QuickTime MP3/MP4 driver failed.\n");
    }
#endif	// SYS_CD_USE_MP3
    
    return (0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Shutdown (void)
{
    // shutdown the audio IO:
    CDAudio_Stop ();

    gCDController = NULL;
    gCDDevice[0] = 0x00;    
    gCurCDTrack = 0;

    if (gCDTrackList != NULL)
    {
       while ([gCDTrackList count])
        {
            NSMovie *	myMovie = [gCDTrackList objectAtIndex: 0];
            
            [gCDTrackList removeObjectAtIndex: 0];
            [myMovie release];
        }
        [gCDTrackList release];
		
        gCDTrackList = NULL;
        gCDTrackCount = 0;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	CD_f (void)
{
    char	*myCommandOption;

    // this command requires options!
    if (Cmd_Argc () < 2)
    {
        return;
    }

    // get the option:
    myCommandOption = Cmd_Argv (1);
    
    // turn CD playback on:
    if (Q_strcasecmp (myCommandOption, "on") == 0)
    {
        if (gCDTrackList == NULL)
        {
            CDAudio_GetTrackList();
        }
        CDAudio_Play(1, 0);
        
		return;
    }
    
    // turn CD playback off:
    if (Q_strcasecmp (myCommandOption, "off") == 0)
    {
        CDAudio_Shutdown ();
        
		return;
    }

    // just for compatibility:
    if (Q_strcasecmp (myCommandOption, "remap") == 0)
    {
        return;
    }

    // reset the current CD:
    if (Q_strcasecmp (myCommandOption, "reset") == 0)
    {
        CDAudio_Stop ();
		
        if (CDAudio_GetTrackList ())
        {
#ifdef SYS_CD_USE_MP3
            if ([[NSApp delegate] mediaFolder] == NULL)
#endif	// SYS_CD_USE_MP3
            {
                Con_Print ("CD");
            }
#ifdef SYS_CD_USE_MP3
            else
            {
                Con_Print ("MP3/MP4 files");
            }
#endif	// SYS_CD_USE_MP3
            Com_Printf (" found. %d tracks (\"%s\").\n", gCDTrackCount, gCDDevice);
		}
        else
        {
            CDAudio_Error (CDERR_NO_FILES_FOUND);
        }
        
	return;
    }
    
    // the following commands require a valid track array, so build it, if not present:
    if (gCDTrackCount == 0)
    {
        CDAudio_GetTrackList ();
        if (gCDTrackCount == 0)
        {
            CDAudio_Error (CDERR_NO_FILES_FOUND);
			
            return;
        }
    }
    
    // play the selected track:
    if (Q_strcasecmp (myCommandOption, "play") == 0)
    {
        CDAudio_Play (atoi (Cmd_Argv (2)), 0);
        
		return;
    }
    
    // loop the selected track:
    if (Q_strcasecmp (myCommandOption, "loop") == 0)
    {
        CDAudio_Play (atoi (Cmd_Argv (2)), 1);
        
		return;
    }
    
    // stop the current track:
    if (Q_strcasecmp (myCommandOption, "stop") == 0)
    {
        CDAudio_Stop ();
        
		return;
    }
    
    // pause the current track:
    if (Q_strcasecmp (myCommandOption, "pause") == 0)
    {
        CDAudio_Pause ();
        
		return;
    }
    
    // resume the current track:
    if (Q_strcasecmp (myCommandOption, "resume") == 0)
    {
        CDAudio_Resume ();
        
		return;
    }
    
    // eject the CD:
#ifdef SYS_CD_USE_MP3
    if ([[NSApp delegate] mediaFolder] == nil && Q_strcasecmp (myCommandOption, "eject") == 0)
#else	// SYS_CD_USE_MP3
	if (Q_strcasecmp (myCommandOption, "eject") == 0)
#endif	// SYS_CD_USE_MP3
    {
        // eject the CD:
        if (gCDDevice[0] != 0x00)
        {
            NSString	*myDevicePath = [NSString stringWithCString: gCDDevice];
            
            if (myDevicePath != NULL)
            {
                CDAudio_Shutdown ();
                
                if (![[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath: myDevicePath])
                {
                    CDAudio_Error (CDERR_EJECT);
                }
            }
            else
            {
                CDAudio_Error (CDERR_EJECT);
            }
        }
        else
        {
            CDAudio_Error (CDERR_NO_MEDIA_FOUND);
        }
        
		return;
    }
    
    // output CD info:
    if (Q_strcasecmp(myCommandOption, "info") == 0)
    {
        if (gCDTrackCount == 0)
        {
            CDAudio_Error (CDERR_NO_FILES_FOUND);
        }
        else
        {
            if (gCDController != NULL && GetMovieActive (gCDController) == YES)
            {
                Com_Printf ("Playing track %d of %d (\"%s\").\n", gCurCDTrack, gCDTrackCount, gCDDevice);
            }
            else
            {
                Com_Printf ("Not playing. Tracks: %d (\"%s\").\n", gCDTrackCount, gCDDevice);
            }
			
            Com_Printf ("Volume is: %.2f.\n", cd_volume->value);
        }
        
		return;
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

qboolean CDAudio_Active (void)
{
	return (gCDController != NULL && GetMovieActive (gCDController) == YES && IsMovieDone (gCDController) == NO);
}

//______________________________________________________________________________________________________________eOF
