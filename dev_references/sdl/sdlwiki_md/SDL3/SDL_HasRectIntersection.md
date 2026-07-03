# SDL_HasRectIntersection

Determine whether two rectangles intersect.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HasRectIntersection(const SDL_Rect *A, const SDL_Rect *B);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_Rect](SDL_Rect.html) \* | **A** | an [SDL_Rect](SDL_Rect.html) structure representing the first rectangle. |
| const [SDL_Rect](SDL_Rect.html) \* | **B** | an [SDL_Rect](SDL_Rect.html) structure representing the second rectangle. |

## Return Value

(bool) Returns true if there is an intersection, false otherwise.

## Remarks

If either pointer is NULL the function will return false.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRectIntersection](SDL_GetRectIntersection.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRect](CategoryRect.html)
