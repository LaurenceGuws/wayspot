# CategoryInit

All SDL programs need to initialize the library before starting to work
with it.

Almost everything can simply call [SDL_Init](SDL_Init.html)() near
startup, with a handful of flags to specify subsystems to touch. These
are here to make sure SDL does not even attempt to touch low-level
pieces of the operating system that you don't intend to use. For
example, you might be using SDL for video and input but chose an
external library for audio, and in this case you would just need to
leave off the [`SDL_INIT_AUDIO`](SDL_INIT_AUDIO.html) flag to make sure
that external library has complete control.

Most apps, when terminating, should call [SDL_Quit](SDL_Quit.html)().
This will clean up (nearly) everything that SDL might have allocated,
and crucially, it'll make sure that the display's resolution is back to
what the user expects if you had previously changed it for your game.

SDL3 apps are strongly encouraged to call
[SDL_SetAppMetadata](SDL_SetAppMetadata.html)() at startup to fill in
details about the program. This is completely optional, but it helps in
small ways (we can provide an About dialog box for the macOS menu, we
can name the app in the system's audio mixer, etc). Those that want to
provide a *lot* of information should look at the more-detailed
[SDL_SetAppMetadataProperty](SDL_SetAppMetadataProperty.html)().

## Functions

- [SDL_GetAppMetadataProperty](SDL_GetAppMetadataProperty.html)
- [SDL_Init](SDL_Init.html)
- [SDL_InitSubSystem](SDL_InitSubSystem.html)
- [SDL_IsMainThread](SDL_IsMainThread.html)
- [SDL_Quit](SDL_Quit.html)
- [SDL_QuitSubSystem](SDL_QuitSubSystem.html)
- [SDL_RunOnMainThread](SDL_RunOnMainThread.html)
- [SDL_SetAppMetadata](SDL_SetAppMetadata.html)
- [SDL_SetAppMetadataProperty](SDL_SetAppMetadataProperty.html)
- [SDL_WasInit](SDL_WasInit.html)

## Datatypes

- [SDL_AppEvent_func](SDL_AppEvent_func.html)
- [SDL_AppInit_func](SDL_AppInit_func.html)
- [SDL_AppIterate_func](SDL_AppIterate_func.html)
- [SDL_AppQuit_func](SDL_AppQuit_func.html)
- [SDL_InitFlags](SDL_InitFlags.html)
- [SDL_MainThreadCallback](SDL_MainThreadCallback.html)

## Structs

- (none.)

## Enums

- [SDL_AppResult](SDL_AppResult.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
