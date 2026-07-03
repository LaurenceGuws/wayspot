# SDL_CreateRWLock

Create a new read/write lock.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_RWLock * SDL_CreateRWLock(void);
```

</div>

## Return Value

([SDL_RWLock](SDL_RWLock.html) \*) Returns the initialized and unlocked
read/write lock or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

A read/write lock is useful for situations where you have multiple
threads trying to access a resource that is rarely updated. All threads
requesting a read-only lock will be allowed to run in parallel; if a
thread requests a write lock, it will be provided exclusive access. This
makes it safe for multiple threads to use a resource at the same time if
they promise not to change it, and when it has to be changed, the rwlock
will serve as a gateway to make sure those changes can be made safely.

In the right situation, a rwlock can be more efficient than a mutex,
which only lets a single thread proceed at a time, even if it won't be
modifying the data.

All newly-created read/write locks begin in the *unlocked* state.

Calls to [SDL_LockRWLockForReading](SDL_LockRWLockForReading.html)() and
[SDL_LockRWLockForWriting](SDL_LockRWLockForWriting.html) will not
return while the rwlock is locked *for writing* by another thread. See
[SDL_TryLockRWLockForReading](SDL_TryLockRWLockForReading.html)() and
[SDL_TryLockRWLockForWriting](SDL_TryLockRWLockForWriting.html)() to
attempt to lock without blocking.

SDL read/write locks are only recursive for read-only locks! They are
not guaranteed to be fair, or provide access in a FIFO manner! They are
not guaranteed to favor writers. You may not lock a rwlock for both
read-only and write access at the same time from the same thread (so you
can't promote your read-only lock to a write lock without unlocking
first).

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroyRWLock](SDL_DestroyRWLock.html)
- [SDL_LockRWLockForReading](SDL_LockRWLockForReading.html)
- [SDL_LockRWLockForWriting](SDL_LockRWLockForWriting.html)
- [SDL_TryLockRWLockForReading](SDL_TryLockRWLockForReading.html)
- [SDL_TryLockRWLockForWriting](SDL_TryLockRWLockForWriting.html)
- [SDL_UnlockRWLock](SDL_UnlockRWLock.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMutex](CategoryMutex.html)
