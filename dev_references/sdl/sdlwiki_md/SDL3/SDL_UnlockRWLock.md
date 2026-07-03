# SDL_UnlockRWLock

Unlock the read/write lock.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_UnlockRWLock(SDL_RWLock *rwlock);
```

</div>

## Function Parameters

|                                  |            |                       |
|----------------------------------|------------|-----------------------|
| [SDL_RWLock](SDL_RWLock.html) \* | **rwlock** | the rwlock to unlock. |

## Remarks

Use this function to unlock the rwlock, whether it was locked for
read-only or write operations.

It is legal for the owning thread to lock an already-locked read-only
lock. It must unlock it the same number of times before it is actually
made available for other threads in the system (this is known as a
"recursive rwlock").

It is illegal to unlock a rwlock that has not been locked by the current
thread, and doing so results in undefined behavior.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LockRWLockForReading](SDL_LockRWLockForReading.html)
- [SDL_LockRWLockForWriting](SDL_LockRWLockForWriting.html)
- [SDL_TryLockRWLockForReading](SDL_TryLockRWLockForReading.html)
- [SDL_TryLockRWLockForWriting](SDL_TryLockRWLockForWriting.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
