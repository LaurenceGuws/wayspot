<div id="content"
class="hx:w-full hx:min-w-0 hextra-max-content-width hx:px-6 hx:pt-4 hx:md:px-12"
role="main">

<div class="hx:mt-1.5 hx:flex hx:items-center hx:gap-1 hx:overflow-hidden hx:text-sm hx:text-gray-500 hx:dark:text-gray-400 hx:contrast-more:text-current">

<div class="hx:whitespace-nowrap hx:transition-colors hx:font-medium hx:text-gray-700 hx:contrast-more:font-bold hx:contrast-more:text-current hx:dark:text-gray-100 hx:contrast-more:dark:text-current">

IPC

</div>

</div>

<div class="content">

<div class="hx:flex hx:flex-col hx:sm:flex-row hx:items-start hx:sm:items-center hx:sm:justify-between hx:gap-4 hx:mb-4">

# IPC

</div>

Hyprland exposes 2 UNIX Sockets, for controlling / getting info about
Hyprland via code / bash utilities.

## Hyprland Instance Signature (HIS)<span id="hyprland-instance-signature-his" class="hx:absolute hx:-mt-20"></span> <a href="index.html#hyprland-instance-signature-his"
class="subheading-anchor" aria-label="Permalink for this section"></a>

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
echo $HYPRLAND_INSTANCE_SIGNATURE
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

## `$XDG_RUNTIME_DIR/hypr/[HIS]/.socket.sock`<span id="xdg_runtime_dirhyprhissocketsock" class="hx:absolute hx:-mt-20"></span> <a href="index.html#xdg_runtime_dirhyprhissocketsock"
class="subheading-anchor" aria-label="Permalink for this section"></a>

Used for hyprctl-like requests. See the [Hyprctl
page](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl)
for commands.

basically, write `[flag(s)]/command args`.

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

Hyprland evaluates connections to this socket completely synchronously,
which means that any unclosed connections *will cause Hyprland to
freeze* until the five-second timeout is reached. Ensure that you always
open the socket immediately before writing requests and close it
afterward.

</div>

</div>

</div>

## `$XDG_RUNTIME_DIR/hypr/[HIS]/.socket2.sock`<span id="xdg_runtime_dirhyprhissocket2sock" class="hx:absolute hx:-mt-20"></span> <a href="index.html#xdg_runtime_dirhyprhissocket2sock"
class="subheading-anchor" aria-label="Permalink for this section"></a>

Used for events. Hyprland will write to each connected client live
events like this:

`EVENT>>DATA\n` (`\n` is a linebreak)

e.g.: `workspace>>2`

## Events list<span id="events-list" class="hx:absolute hx:-mt-20"></span> <a href="index.html#events-list" class="subheading-anchor"
aria-label="Permalink for this section"></a>

<table>
<colgroup>
<col style="width: 33%" />
<col style="width: 33%" />
<col style="width: 33%" />
</colgroup>
<thead>
<tr>
<th>name</th>
<th>description</th>
<th>data</th>
</tr>
</thead>
<tbody>
<tr>
<td>workspace</td>
<td>emitted on workspace change. Is emitted ONLY when a user requests a
workspace change, and is not emitted on mouse movements (see
<code>focusedmon</code>)</td>
<td><code>WORKSPACENAME</code></td>
</tr>
<tr>
<td>workspacev2</td>
<td>emitted on workspace change. Is emitted ONLY when a user requests a
workspace change, and is not emitted on mouse movements (see
<code>focusedmon</code>)</td>
<td><code>WORKSPACEID,WORKSPACENAME</code></td>
</tr>
<tr>
<td>focusedmon</td>
<td>emitted on the active monitor being changed.</td>
<td><code>MONNAME,WORKSPACENAME</code></td>
</tr>
<tr>
<td>focusedmonv2</td>
<td>emitted on the active monitor being changed.</td>
<td><code>MONNAME,WORKSPACEID</code></td>
</tr>
<tr>
<td>activewindow</td>
<td>emitted on the active window being changed.</td>
<td><code>WINDOWCLASS,WINDOWTITLE</code></td>
</tr>
<tr>
<td>activewindowv2</td>
<td>emitted on the active window being changed.</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>fullscreen</td>
<td>emitted when a fullscreen status of a window changes.</td>
<td><code>0/1</code> (exit fullscreen / enter fullscreen)</td>
</tr>
<tr>
<td>monitorremoved</td>
<td>emitted when a monitor is removed (disconnected)</td>
<td><code>MONITORNAME</code></td>
</tr>
<tr>
<td>monitorremovedv2</td>
<td>emitted when a monitor is removed (disconnected)</td>
<td><code>MONITORID,MONITORNAME,MONITORDESCRIPTION</code></td>
</tr>
<tr>
<td>monitoradded</td>
<td>emitted when a monitor is added (connected)</td>
<td><code>MONITORNAME</code></td>
</tr>
<tr>
<td>monitoraddedv2</td>
<td>emitted when a monitor is added (connected)</td>
<td><code>MONITORID,MONITORNAME,MONITORDESCRIPTION</code></td>
</tr>
<tr>
<td>createworkspace</td>
<td>emitted when a workspace is created</td>
<td><code>WORKSPACENAME</code></td>
</tr>
<tr>
<td>createworkspacev2</td>
<td>emitted when a workspace is created</td>
<td><code>WORKSPACEID,WORKSPACENAME</code></td>
</tr>
<tr>
<td>destroyworkspace</td>
<td>emitted when a workspace is destroyed</td>
<td><code>WORKSPACENAME</code></td>
</tr>
<tr>
<td>destroyworkspacev2</td>
<td>emitted when a workspace is destroyed</td>
<td><code>WORKSPACEID,WORKSPACENAME</code></td>
</tr>
<tr>
<td>moveworkspace</td>
<td>emitted when a workspace is moved to a different monitor</td>
<td><code>WORKSPACENAME,MONNAME</code></td>
</tr>
<tr>
<td>moveworkspacev2</td>
<td>emitted when a workspace is moved to a different monitor</td>
<td><code>WORKSPACEID,WORKSPACENAME,MONNAME</code></td>
</tr>
<tr>
<td>renameworkspace</td>
<td>emitted when a workspace is renamed</td>
<td><code>WORKSPACEID,NEWNAME</code></td>
</tr>
<tr>
<td>activespecial</td>
<td>emitted when the special workspace opened in a monitor changes
(closing results in an empty <code>WORKSPACENAME</code>)</td>
<td><code>WORKSPACENAME,MONNAME</code></td>
</tr>
<tr>
<td>activespecialv2</td>
<td>emitted when the special workspace opened in a monitor changes
(closing results in empty <code>WORKSPACEID</code> and
<code>WORKSPACENAME</code> values)</td>
<td><code>WORKSPACEID,WORKSPACENAME,MONNAME</code></td>
</tr>
<tr>
<td>activelayout</td>
<td>emitted on a layout change of the active keyboard</td>
<td><code>KEYBOARDNAME,LAYOUTNAME</code></td>
</tr>
<tr>
<td>openwindow</td>
<td>emitted when a window is opened</td>
<td><code>WINDOWADDRESS</code>,<code>WORKSPACENAME</code>,<code>WINDOWCLASS</code>,<code>WINDOWTITLE</code></td>
</tr>
<tr>
<td>closewindow</td>
<td>emitted when a window is closed</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>kill</td>
<td>emitted when a window is killed (via <code>hyprctl kill</code>)</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>movewindow</td>
<td>emitted when a window is moved to a workspace</td>
<td><code>WINDOWADDRESS</code>,<code>WORKSPACENAME</code></td>
</tr>
<tr>
<td>movewindowv2</td>
<td>emitted when a window is moved to a workspace</td>
<td><code>WINDOWADDRESS</code>,<code>WORKSPACEID</code>,<code>WORKSPACENAME</code></td>
</tr>
<tr>
<td>openlayer</td>
<td>emitted when a layerSurface is mapped</td>
<td><code>NAMESPACE</code></td>
</tr>
<tr>
<td>closelayer</td>
<td>emitted when a layerSurface is unmapped</td>
<td><code>NAMESPACE</code></td>
</tr>
<tr>
<td>submap</td>
<td>emitted when a keybind submap changes. Empty means default.</td>
<td><code>SUBMAPNAME</code></td>
</tr>
<tr>
<td>changefloatingmode</td>
<td>emitted when a window changes its floating mode.
<code>FLOATING</code> is either 0 or 1.</td>
<td><code>WINDOWADDRESS</code>,<code>FLOATING</code></td>
</tr>
<tr>
<td>urgent</td>
<td>emitted when a window requests an <code>urgent</code> state</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>screencast</td>
<td>emitted when a screencopy state of a client changes. Keep in mind
there might be multiple separate clients. State is 0/1, owner is
monitor/window/region</td>
<td><code>STATE,OWNER</code></td>
</tr>
<tr>
<td>screencastv2</td>
<td>emitted when a screencopy state of a client changes. Keep in mind
there might be multiple separate clients. State is 0/1, owner is
monitor/window/region, name is the identifier of the shared target
(monitor name or window title)</td>
<td><code>STATE,OWNER,NAME</code></td>
</tr>
<tr>
<td>windowtitle</td>
<td>emitted when a window title changes.</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>windowtitlev2</td>
<td>emitted when a window title changes.</td>
<td><code>WINDOWADDRESS,WINDOWTITLE</code></td>
</tr>
<tr>
<td>togglegroup</td>
<td>emitted when <code>togglegroup</code> command is used.<br />
returns <code>state,handle</code> where the <code>state</code> is a
toggle status and the <code>handle</code> is one or more window
addresses separated by a comma<br />
e.g. <code>0,64cea2525760,64cea2522380</code> where <code>0</code> means
that a group has been destroyed and the rest informs which windows were
part of it</td>
<td><code>0/1,WINDOWADDRESS(ES)</code></td>
</tr>
<tr>
<td>moveintogroup</td>
<td>emitted when the window is merged into a group. returns the address
of a merged window</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>moveoutofgroup</td>
<td>emitted when the window is removed from a group. returns the address
of a removed window</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
<tr>
<td>ignoregrouplock</td>
<td>emitted when <code>ignoregrouplock</code> is toggled.</td>
<td><code>0/1</code></td>
</tr>
<tr>
<td>lockgroups</td>
<td>emitted when <code>lockgroups</code> is toggled.</td>
<td><code>0/1</code></td>
</tr>
<tr>
<td>configreloaded</td>
<td>emitted when the config is done reloading</td>
<td>empty</td>
</tr>
<tr>
<td>pin</td>
<td>emitted when a window is pinned or unpinned</td>
<td><code>WINDOWADDRESS,PINSTATE</code></td>
</tr>
<tr>
<td>minimized</td>
<td>emitted when an external taskbar-like app requests a window to be
minimized</td>
<td><code>WINDOWADDRESS,0/1</code></td>
</tr>
<tr>
<td>bell</td>
<td>emitted when an app requests to ring the system bell via
<code>xdg-system-bell-v1</code>. Window address parameter may be
empty.</td>
<td><code>WINDOWADDRESS</code></td>
</tr>
</tbody>
</table>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

A fullscreen event is not guaranteed to fire on/off once in succession.
Some windows may fire multiple requests to be fullscreened, resulting in
multiple fullscreen events.

</div>

</div>

</div>

## How to use socket2 with bash<span id="how-to-use-socket2-with-bash" class="hx:absolute hx:-mt-20"></span> <a href="index.html#how-to-use-socket2-with-bash"
class="subheading-anchor" aria-label="Permalink for this section"></a>

Example script using socket2 events with bash and `socat`:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
#!/bin/sh

handle() {
  case $1 in
    monitoradded*) do_something ;;
    focusedmon*) do_something_else ;;
  esac
}

socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
```

</div>

</div>

<div class="hextra-code-copy-btn-container hx:opacity-0 hx:transition hx:group-hover/code:opacity-100 hx:flex hx:gap-1 hx:absolute hx:m-[11px] hx:right-0 hx:top-0">

<div class="hextra-copy-icon hx:group-[.copied]/copybtn:hidden hx:pointer-events-none hx:h-4 hx:w-4">

</div>

<div class="hextra-success-icon hx:hidden hx:group-[.copied]/copybtn:block hx:pointer-events-none hx:h-4 hx:w-4">

</div>

</div>

</div>

</div>

<div class="hx:mt-12 hx:mb-8 hx:block hx:text-xs hx:text-gray-500 hx:ltr:text-right hx:rtl:text-left hx:dark:text-gray-400">

Last updated on July 3, 2026

</div>

</div>
