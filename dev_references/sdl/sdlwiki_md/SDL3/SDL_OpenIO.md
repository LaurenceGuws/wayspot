# SDL_OpenIO

Create a custom [SDL_IOStream](SDL_IOStream.html).

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStream * SDL_OpenIO(const SDL_IOStreamInterface *iface, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_IOStreamInterface](SDL_IOStreamInterface.html) \* | **iface** | the interface that implements this [SDL_IOStream](SDL_IOStream.html), initialized using [SDL_INIT_INTERFACE](SDL_INIT_INTERFACE.html)(). |
| void \* | **userdata** | the pointer that will be passed to the interface functions. |

## Return Value

([SDL_IOStream](SDL_IOStream.html) \*) Returns a pointer to the
allocated memory on success or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Applications do not need to use this function unless they are providing
their own [SDL_IOStream](SDL_IOStream.html) implementation. If you just
need an [SDL_IOStream](SDL_IOStream.html) to read/write a common data
source, you should use the built-in implementations in SDL, like
[SDL_IOFromFile](SDL_IOFromFile.html)() or
[SDL_IOFromMem](SDL_IOFromMem.html)(), etc.

This function makes a copy of `iface` and the caller does not need to
keep it around after this call.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseIO](SDL_CloseIO.html)
- [SDL_INIT_INTERFACE](SDL_INIT_INTERFACE.html)
- [SDL_IOFromConstMem](SDL_IOFromConstMem.html)
- [SDL_IOFromFile](SDL_IOFromFile.html)
- [SDL_IOFromMem](SDL_IOFromMem.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
