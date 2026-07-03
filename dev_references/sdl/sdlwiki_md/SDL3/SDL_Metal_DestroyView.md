# SDL_Metal_DestroyView

Destroy an existing [SDL_MetalView](SDL_MetalView.html) object.

## Header File

Defined in
[\<SDL3/SDL_metal.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_metal.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_Metal_DestroyView(SDL_MetalView view);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_MetalView](SDL_MetalView.html) | **view** | the [SDL_MetalView](SDL_MetalView.html) object. |

## Remarks

This should be called before
[SDL_DestroyWindow](SDL_DestroyWindow.html), if
[SDL_Metal_CreateView](SDL_Metal_CreateView.html) was called after
[SDL_CreateWindow](SDL_CreateWindow.html).

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Metal_CreateView](SDL_Metal_CreateView.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMetal](CategoryMetal.html)
