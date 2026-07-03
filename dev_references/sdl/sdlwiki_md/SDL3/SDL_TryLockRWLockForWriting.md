# SDL_TryLockRWLockForWriting

Try to lock a read/write lock *for writing* without blocking.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_TryLockRWLockForWriting(SDL_RWLock *rwlock);
```

</div>

## Function Parameters

|                                  |            |                            |
|----------------------------------|------------|----------------------------|
| [SDL_RWLock](SDL_RWLock.html) \* | **rwlock** | the rwlock to try to lock. |

## Return Value

(bool) Returns true on success, false if the lock would block.

## Remarks

This works just like
[SDL_LockRWLockForWriting](SDL_LockRWLockForWriting.html)(), but if the
rwlock is not available, then this function returns false immediately.

This technique is useful if you need exclusive access to a resource but
don't want to wait for it, and will return to it to try again later.

It is illegal for the owning thread to lock an already-locked rwlock for
writing (read-only may be locked recursively, writing can not). Doing so
results in undefined behavior.

It is illegal to request a write lock from a thread that already holds a
read-only lock. Doing so results in undefined behavior. Unlock the
read-only lock before requesting a write lock.

This function returns true if passed a NULL rwlock.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LockRWLockForWriting](SDL_LockRWLockForWriting.html)
- [SDL_TryLockRWLockForReading](SDL_TryLockRWLockForReading.html)
- [SDL_UnlockRWLock](SDL_UnlockRWLock.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
