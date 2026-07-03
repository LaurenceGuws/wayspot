# SDL_InitFlags

Initialization flags for [SDL_Init](SDL_Init.html) and/or
[SDL_InitSubSystem](SDL_InitSubSystem.html)

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef Uint32 SDL_InitFlags;

#define SDL_INIT_AUDIO      0x00000010u /**< `SDL_INIT_AUDIO` implies `SDL_INIT_EVENTS` */
#define SDL_INIT_VIDEO      0x00000020u /**< `SDL_INIT_VIDEO` implies `SDL_INIT_EVENTS`, should be initialized on the main thread */
#define SDL_INIT_JOYSTICK   0x00000200u /**< `SDL_INIT_JOYSTICK` implies `SDL_INIT_EVENTS` */
#define SDL_INIT_HAPTIC     0x00001000u
#define SDL_INIT_GAMEPAD    0x00002000u /**< `SDL_INIT_GAMEPAD` implies `SDL_INIT_JOYSTICK` */
#define SDL_INIT_EVENTS     0x00004000u
#define SDL_INIT_SENSOR     0x00008000u /**< `SDL_INIT_SENSOR` implies `SDL_INIT_EVENTS` */
#define SDL_INIT_CAMERA     0x00010000u /**< `SDL_INIT_CAMERA` implies `SDL_INIT_EVENTS` */
```

</div>

## Remarks

These are the flags which may be passed to [SDL_Init](SDL_Init.html)().
You should specify the subsystems which you will be using in your
application.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_Init](SDL_Init.html)
- [SDL_Quit](SDL_Quit.html)
- [SDL_InitSubSystem](SDL_InitSubSystem.html)
- [SDL_QuitSubSystem](SDL_QuitSubSystem.html)
- [SDL_WasInit](SDL_WasInit.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryInit](CategoryInit.html)
