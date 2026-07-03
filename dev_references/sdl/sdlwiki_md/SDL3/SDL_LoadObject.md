# SDL_LoadObject

Dynamically load a shared object.

## Header File

Defined in
[\<SDL3/SDL_loadso.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_loadso.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_SharedObject * SDL_LoadObject(const char *sofile);
```

</div>

## Function Parameters

|               |            |                                             |
|---------------|------------|---------------------------------------------|
| const char \* | **sofile** | a system-dependent name of the object file. |

## Return Value

([SDL_SharedObject](SDL_SharedObject.html) \*) Returns an opaque pointer
to the object handle or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LoadFunction](SDL_LoadFunction.html)
- [SDL_UnloadObject](SDL_UnloadObject.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySharedObject](CategorySharedObject.html)
