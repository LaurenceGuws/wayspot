# SDL_GetSemaphoreValue

Get the current value of a semaphore.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint32 SDL_GetSemaphoreValue(SDL_Semaphore *sem);
```

</div>

## Function Parameters

|                                        |         |                         |
|----------------------------------------|---------|-------------------------|
| [SDL_Semaphore](SDL_Semaphore.html) \* | **sem** | the semaphore to query. |

## Return Value

([Uint32](Uint32.html)) Returns the current value of the semaphore.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
