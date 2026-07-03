# SDL_SendAndroidMessage

Send a user command to SDLActivity.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SendAndroidMessage(Uint32 command, int param);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint32](Uint32.html) | **command** | user command that must be greater or equal to 0x8000. |
| int | **param** | user parameter. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Override "boolean onUnhandledMessage(Message msg)" to handle the
message.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
