###### (This function is part of SDL_net, a separate library from SDL.)

# NET_GetAddressStatus

Check if an address is resolved, without blocking.

## Header File

Defined in
[\<SDL3_net/SDL_net.h\>](https://github.com/libsdl-org/SDL_net/blob/main/include/SDL3_net/SDL_net.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
NET_Status NET_GetAddressStatus(NET_Address *address);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [NET_Address](NET_Address.html) \* | **address** | The [NET_Address](NET_Address.html) to query. |

## Return Value

([NET_Status](NET_Status.html)) Returns [NET_SUCCESS](NET_SUCCESS.html)
if successfully resolved, [NET_FAILURE](NET_FAILURE.html) if resolution
failed, [NET_WAITING](NET_WAITING.html) if still resolving (this
function timed out without resolution); if
[NET_FAILURE](NET_FAILURE.html), call SDL_GetError() for details.

## Remarks

The [NET_Address](NET_Address.html) objects returned by
[NET_ResolveHostname](NET_ResolveHostname.html) take time to do their
work, so it does so *asynchronously* instead of making your program wait
an indefinite amount of time.

This function allows you to check the progress of that work without
blocking.

Resolution can fail after some time (DNS server took awhile to reply
that the hostname isn't recognized, etc), so be sure to check the result
of this function instead of assuming it worked because it's non-zero!

Once an address is successfully resolved, it can be used to connect to
the host represented by the address.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_net 3.0.0.

## See Also

- [NET_WaitUntilResolved](NET_WaitUntilResolved.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLNet](CategorySDLNet.html)
