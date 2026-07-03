# SDL_GetRectIntersection

Calculate the intersection of two rectangles.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRectIntersection(const SDL_Rect *A, const SDL_Rect *B, SDL_Rect *result);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_Rect](SDL_Rect.html) \* | **A** | an [SDL_Rect](SDL_Rect.html) structure representing the first rectangle. |
| const [SDL_Rect](SDL_Rect.html) \* | **B** | an [SDL_Rect](SDL_Rect.html) structure representing the second rectangle. |
| [SDL_Rect](SDL_Rect.html) \* | **result** | an [SDL_Rect](SDL_Rect.html) structure filled in with the intersection of rectangles `A` and `B`. |

## Return Value

(bool) Returns true if there is an intersection, false otherwise.

## Remarks

If `result` is NULL then this function will return false.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasRectIntersection](SDL_HasRectIntersection.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRect](CategoryRect.html)
