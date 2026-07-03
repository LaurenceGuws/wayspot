# SDL_DestroyCondition

Destroy a condition variable.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyCondition(SDL_Condition *cond);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Condition](SDL_Condition.html) \* | **cond** | the condition variable to destroy. |

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateCondition](SDL_CreateCondition.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
