# SDL_SetiOSAnimationCallback

Use this function to set the animation callback on Apple iOS.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetiOSAnimationCallback(SDL_Window *window, int interval, SDL_iOSAnimationCallback callback, void *callbackParam);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window for which the animation callback should be set. |
| int | **interval** | the number of frames after which **callback** will be called. |
| [SDL_iOSAnimationCallback](SDL_iOSAnimationCallback.html) | **callback** | the function to call for every frame. |
| void \* | **callbackParam** | a pointer that is passed to `callback`. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The function prototype for `callback` is:

<div id="cb2" class="sourceCode">

``` sourceCode
void callback(void *callbackParam);
```

</div>

Where its parameter, `callbackParam`, is what was passed as
`callbackParam` to
[SDL_SetiOSAnimationCallback](SDL_SetiOSAnimationCallback.html)().

This function is only available on Apple iOS.

For more information see:

[https://wiki.libsdl.org/SDL3/README-ios](README-ios.html)

Note that if you use the "main callbacks" instead of a standard C `main`
function, you don't have to use this API, as SDL will manage this for
you.

Details on main callbacks are here:

[https://wiki.libsdl.org/SDL3/README-main-functions](README-main-functions.html)

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetiOSEventPump](SDL_SetiOSEventPump.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
