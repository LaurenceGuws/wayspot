# SDL_GetGDKDefaultUser

Gets a reference to the default user handle for GDK.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetGDKDefaultUser(XUserHandle *outUserHandle);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| XUserHandle \* | **outUserHandle** | a pointer to be filled in with the default user handle. |

## Return Value

(bool) Returns true if success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This is effectively a synchronous version of XUserAddAsync, which always
prefers the default user and allows a sign-in UI.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
