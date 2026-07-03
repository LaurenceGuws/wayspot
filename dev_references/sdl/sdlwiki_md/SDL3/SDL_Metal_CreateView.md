# SDL_Metal_CreateView

Create a CAMetalLayer-backed NSView/UIView and attach it to the
specified window.

## Header File

Defined in
[\<SDL3/SDL_metal.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_metal.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_MetalView SDL_Metal_CreateView(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |             |
|----------------------------------|------------|-------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window. |

## Return Value

([SDL_MetalView](SDL_MetalView.html)) Returns handle NSView or UIView.

## Remarks

On macOS, this does *not* associate a MTLDevice with the CAMetalLayer on
its own. It is up to user code to do that.

The returned handle can be casted directly to a NSView or UIView. To
access the backing CAMetalLayer, call
[SDL_Metal_GetLayer](SDL_Metal_GetLayer.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Metal_DestroyView](SDL_Metal_DestroyView.html)
- [SDL_Metal_GetLayer](SDL_Metal_GetLayer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMetal](CategoryMetal.html)
