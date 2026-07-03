# SDL_GetRectUnionFloat

Calculate the union of two rectangles with float precision.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRectUnionFloat(const SDL_FRect *A, const SDL_FRect *B, SDL_FRect *result);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_FRect](SDL_FRect.html) \* | **A** | an [SDL_FRect](SDL_FRect.html) structure representing the first rectangle. |
| const [SDL_FRect](SDL_FRect.html) \* | **B** | an [SDL_FRect](SDL_FRect.html) structure representing the second rectangle. |
| [SDL_FRect](SDL_FRect.html) \* | **result** | an [SDL_FRect](SDL_FRect.html) structure filled in with the union of rectangles `A` and `B`. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRect](CategoryRect.html)
