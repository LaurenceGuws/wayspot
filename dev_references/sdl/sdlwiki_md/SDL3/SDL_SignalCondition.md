# SDL_SignalCondition

Restart one of the threads that are waiting on the condition variable.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SignalCondition(SDL_Condition *cond);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Condition](SDL_Condition.html) \* | **cond** | the condition variable to signal. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_BroadcastCondition](SDL_BroadcastCondition.html)
- [SDL_WaitCondition](SDL_WaitCondition.html)
- [SDL_WaitConditionTimeout](SDL_WaitConditionTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
