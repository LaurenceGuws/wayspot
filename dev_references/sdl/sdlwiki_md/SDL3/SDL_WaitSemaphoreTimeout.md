# SDL_WaitSemaphoreTimeout

Wait until a semaphore has a positive value and then decrements it.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WaitSemaphoreTimeout(SDL_Semaphore *sem, Sint32 timeoutMS);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Semaphore](SDL_Semaphore.html) \* | **sem** | the semaphore to wait on. |
| [Sint32](Sint32.html) | **timeoutMS** | the length of the timeout, in milliseconds, or -1 to wait indefinitely. |

## Return Value

(bool) Returns true if the wait succeeds or false if the wait times out.

## Remarks

This function suspends the calling thread until either the semaphore
pointed to by `sem` has a positive value or the specified time has
elapsed. If the call is successful it will atomically decrement the
semaphore value.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SignalSemaphore](SDL_SignalSemaphore.html)
- [SDL_TryWaitSemaphore](SDL_TryWaitSemaphore.html)
- [SDL_WaitSemaphore](SDL_WaitSemaphore.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
