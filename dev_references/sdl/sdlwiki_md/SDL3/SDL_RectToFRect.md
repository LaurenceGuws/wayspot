# SDL_RectToFRect

Convert an [SDL_Rect](SDL_Rect.html) to [SDL_FRect](SDL_FRect.html)

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_FORCE_INLINE void SDL_RectToFRect(const SDL_Rect *rect, SDL_FRect *frect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_Rect](SDL_Rect.html) \* | **rect** | a pointer to an [SDL_Rect](SDL_Rect.html). |
| [SDL_FRect](SDL_FRect.html) \* | **frect** | a pointer filled in with the floating point representation of `rect`. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRect](CategoryRect.html)
