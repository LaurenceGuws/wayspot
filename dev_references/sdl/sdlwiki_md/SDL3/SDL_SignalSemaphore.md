# SDL_SignalSemaphore

Atomically increment a semaphore's value and wake waiting threads.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SignalSemaphore(SDL_Semaphore *sem);
```

</div>

## Function Parameters

|                                        |         |                             |
|----------------------------------------|---------|-----------------------------|
| [SDL_Semaphore](SDL_Semaphore.html) \* | **sem** | the semaphore to increment. |

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_TryWaitSemaphore](SDL_TryWaitSemaphore.html)
- [SDL_WaitSemaphore](SDL_WaitSemaphore.html)
- [SDL_WaitSemaphoreTimeout](SDL_WaitSemaphoreTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
