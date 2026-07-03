# SDL_LockMutex

Lock the mutex.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_LockMutex(SDL_Mutex *mutex);
```

</div>

## Function Parameters

|                                |           |                    |
|--------------------------------|-----------|--------------------|
| [SDL_Mutex](SDL_Mutex.html) \* | **mutex** | the mutex to lock. |

## Remarks

This will block until the mutex is available, which is to say it is in
the unlocked state and the OS has chosen the caller as the next thread
to lock it. Of all threads waiting to lock the mutex, only one may do so
at a time.

It is legal for the owning thread to lock an already-locked mutex. It
must unlock it the same number of times before it is actually made
available for other threads in the system (this is known as a "recursive
mutex").

This function does not fail; if mutex is NULL, it will return
immediately having locked nothing. If the mutex is valid, this function
will always block until it can lock the mutex, and return with it
locked.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_TryLockMutex](SDL_TryLockMutex.html)
- [SDL_UnlockMutex](SDL_UnlockMutex.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
