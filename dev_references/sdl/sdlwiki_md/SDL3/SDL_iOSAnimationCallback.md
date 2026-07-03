# SDL_iOSAnimationCallback

The prototype for an Apple iOS animation callback.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_iOSAnimationCallback)(void *userdata);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **userdata** | what was passed as `callbackParam` to [SDL_SetiOSAnimationCallback](SDL_SetiOSAnimationCallback.html) as `callbackParam`. |

## Remarks

This datatype is only useful on Apple iOS.

After passing a function pointer of this type to
[SDL_SetiOSAnimationCallback](SDL_SetiOSAnimationCallback.html), the
system will call that function pointer at a regular interval.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_SetiOSAnimationCallback](SDL_SetiOSAnimationCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySystem](CategorySystem.html)
