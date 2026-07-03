# SDL_Init

Initialize the SDL library.

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_Init(SDL_InitFlags flags);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_InitFlags](SDL_InitFlags.html) | **flags** | subsystem initialization flags. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

[SDL_Init](SDL_Init.html)() simply forwards to calling
[SDL_InitSubSystem](SDL_InitSubSystem.html)(). Therefore, the two may be
used interchangeably. Though for readability of your code
[SDL_InitSubSystem](SDL_InitSubSystem.html)() might be preferred.

The file I/O (for example: [SDL_IOFromFile](SDL_IOFromFile.html)) and
threading ([SDL_CreateThread](SDL_CreateThread.html)) subsystems are
initialized by default. Message boxes
([SDL_ShowSimpleMessageBox](SDL_ShowSimpleMessageBox.html)) also attempt
to work without initializing the video subsystem, in hopes of being
useful in showing an error dialog when [SDL_Init](SDL_Init.html) fails.
You must specifically initialize other subsystems if you use them in
your application.

Logging (such as [SDL_Log](SDL_Log.html)) works without initialization,
too.

`flags` may be any of the following OR'd together:

- [`SDL_INIT_AUDIO`](SDL_INIT_AUDIO.html): audio subsystem;
  automatically initializes the events subsystem
- [`SDL_INIT_VIDEO`](SDL_INIT_VIDEO.html): video subsystem;
  automatically initializes the events subsystem, should be initialized
  on the main thread.
- [`SDL_INIT_JOYSTICK`](SDL_INIT_JOYSTICK.html): joystick subsystem;
  automatically initializes the events subsystem
- [`SDL_INIT_HAPTIC`](SDL_INIT_HAPTIC.html): haptic (force feedback)
  subsystem
- [`SDL_INIT_GAMEPAD`](SDL_INIT_GAMEPAD.html): gamepad subsystem;
  automatically initializes the joystick subsystem
- [`SDL_INIT_EVENTS`](SDL_INIT_EVENTS.html): events subsystem
- [`SDL_INIT_SENSOR`](SDL_INIT_SENSOR.html): sensor subsystem;
  automatically initializes the events subsystem
- [`SDL_INIT_CAMERA`](SDL_INIT_CAMERA.html): camera subsystem;
  automatically initializes the events subsystem

Subsystem initialization is ref-counted, you must call
[SDL_QuitSubSystem](SDL_QuitSubSystem.html)() for each
[SDL_InitSubSystem](SDL_InitSubSystem.html)() to correctly shutdown a
subsystem manually (or call [SDL_Quit](SDL_Quit.html)() to force
shutdown). If a subsystem is already loaded then this call will increase
the ref-count and return.

Consider reporting some basic metadata about your application before
calling [SDL_Init](SDL_Init.html), using either
[SDL_SetAppMetadata](SDL_SetAppMetadata.html)() or
[SDL_SetAppMetadataProperty](SDL_SetAppMetadataProperty.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetAppMetadata](SDL_SetAppMetadata.html)
- [SDL_SetAppMetadataProperty](SDL_SetAppMetadataProperty.html)
- [SDL_InitSubSystem](SDL_InitSubSystem.html)
- [SDL_Quit](SDL_Quit.html)
- [SDL_SetMainReady](SDL_SetMainReady.html)
- [SDL_WasInit](SDL_WasInit.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryInit](CategoryInit.html)
