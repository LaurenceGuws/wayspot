# SDL_WaitSemaphore

Wait until a semaphore has a positive value and then decrements it.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_WaitSemaphore(SDL_Semaphore *sem);
```

</div>

## Function Parameters

|                                        |         |                        |
|----------------------------------------|---------|------------------------|
| [SDL_Semaphore](SDL_Semaphore.html) \* | **sem** | the semaphore wait on. |

## Remarks

This function suspends the calling thread until the semaphore pointed to
by `sem` has a positive value, and then atomically decrement the
semaphore value.

This function is the equivalent of calling
[SDL_WaitSemaphoreTimeout](SDL_WaitSemaphoreTimeout.html)() with a time
length of -1.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SignalSemaphore](SDL_SignalSemaphore.html)
- [SDL_TryWaitSemaphore](SDL_TryWaitSemaphore.html)
- [SDL_WaitSemaphoreTimeout](SDL_WaitSemaphoreTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
