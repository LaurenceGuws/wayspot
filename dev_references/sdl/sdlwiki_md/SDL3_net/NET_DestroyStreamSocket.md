###### (This function is part of SDL_net, a separate library from SDL.)

# NET_DestroyStreamSocket

Dispose of a previously-created stream socket.

## Header File

Defined in
[\<SDL3_net/SDL_net.h\>](https://github.com/libsdl-org/SDL_net/blob/main/include/SDL3_net/SDL_net.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void NET_DestroyStreamSocket(NET_StreamSocket *sock);  /* Destroy your sockets when finished with them. Does not block, handles shutdown internally. */
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [NET_StreamSocket](NET_StreamSocket.html) \* | **sock** | stream socket to destroy. |

## Remarks

This will immediately disconnect the other side of the connection, if
necessary. Further attempts to read or write the socket on the remote
end will fail.

This will *abandon* any data queued for sending that hasn't made it to
the socket. If you need this data to arrive, you should wait for it to
transmit before destroying the socket with
[NET_GetStreamSocketPendingWrites](NET_GetStreamSocketPendingWrites.html)()
or
[NET_WaitUntilStreamSocketDrained](NET_WaitUntilStreamSocketDrained.html)().
Any data that has arrived from the remote end of the connection that
hasn't been read yet is lost.

## Thread Safety

You should not operate on the same socket from multiple threads at the
same time without supplying a serialization mechanism. However,
different threads may access different sockets at the same time without
problems.

## Version

This function is available since SDL_net 3.0.0.

## See Also

- [NET_CreateClient](NET_CreateClient.html)
- [NET_AcceptClient](NET_AcceptClient.html)
- [NET_GetStreamSocketPendingWrites](NET_GetStreamSocketPendingWrites.html)
- [NET_WaitUntilStreamSocketDrained](NET_WaitUntilStreamSocketDrained.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLNet](CategorySDLNet.html)
