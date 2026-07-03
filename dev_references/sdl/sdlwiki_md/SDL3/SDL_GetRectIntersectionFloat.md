# SDL_GetRectIntersectionFloat

Calculate the intersection of two rectangles with float precision.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRectIntersectionFloat(const SDL_FRect *A, const SDL_FRect *B, SDL_FRect *result);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_FRect](SDL_FRect.html) \* | **A** | an [SDL_FRect](SDL_FRect.html) structure representing the first rectangle. |
| const [SDL_FRect](SDL_FRect.html) \* | **B** | an [SDL_FRect](SDL_FRect.html) structure representing the second rectangle. |
| [SDL_FRect](SDL_FRect.html) \* | **result** | an [SDL_FRect](SDL_FRect.html) structure filled in with the intersection of rectangles `A` and `B`. |

## Return Value

(bool) Returns true if there is an intersection, false otherwise.

## Remarks

If `result` is NULL then this function will return false.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasRectIntersectionFloat](SDL_HasRectIntersectionFloat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRect](CategoryRect.html)
