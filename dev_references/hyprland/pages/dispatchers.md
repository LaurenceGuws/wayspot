<div id="content"
class="hx:w-full hx:min-w-0 hextra-max-content-width hx:px-6 hx:pt-4 hx:md:px-12"
role="main">

<div class="hx:mt-1.5 hx:flex hx:items-center hx:gap-1 hx:overflow-hidden hx:text-sm hx:text-gray-500 hx:dark:text-gray-400 hx:contrast-more:text-current">

<div class="hx:whitespace-nowrap hx:transition-colors hx:min-w-[24px] hx:overflow-hidden hx:text-ellipsis hx:hover:text-gray-900 hx:dark:hover:text-gray-100">

<a href="https://wiki.hypr.land/Configuring/"
class="hx:inline-block hx:rounded-sm hx:hextra-focus-visible-inset">Configuring</a>

</div>

<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6dy0zLjUgaHg6c2hyaW5rLTAgaHg6cnRsOi1yb3RhdGUtMTgwIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik05IDVsNyA3LTcgNyIgLz48L3N2Zz4="
class="hx:w-3.5 hx:shrink-0 hx:rtl:-rotate-180" />

<div class="hx:whitespace-nowrap hx:transition-colors hx:min-w-[24px] hx:overflow-hidden hx:text-ellipsis hx:hover:text-gray-900 hx:dark:hover:text-gray-100">

<a href="https://wiki.hypr.land/Configuring/Basics/"
class="hx:inline-block hx:rounded-sm hx:hextra-focus-visible-inset">Basics</a>

</div>

<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6dy0zLjUgaHg6c2hyaW5rLTAgaHg6cnRsOi1yb3RhdGUtMTgwIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik05IDVsNyA3LTcgNyIgLz48L3N2Zz4="
class="hx:w-3.5 hx:shrink-0 hx:rtl:-rotate-180" />

<div class="hx:whitespace-nowrap hx:transition-colors hx:font-medium hx:text-gray-700 hx:contrast-more:font-bold hx:contrast-more:text-current hx:dark:text-gray-100 hx:contrast-more:dark:text-current">

Dispatchers

</div>

</div>

<div class="content">

<div class="hx:flex hx:flex-col hx:sm:flex-row hx:items-start hx:sm:items-center hx:sm:justify-between hx:gap-4 hx:mb-4">

# Dispatchers

</div>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

Looking for the old hyprlang syntax? Check the
<a href="https://wiki.hypr.land/0.54.0/" target="_blank"
rel="noopener">0.54 wiki pages</a>. Since Hyprland 0.55, hyprlang is
deprecated in favor of lua.

</div>

</div>

</div>

Please keep in mind some layout-specific dispatchers will be listed in
the layout pages (See the sidebar).

## Dispatchers<span id="dispatchers" class="hx:absolute hx:-mt-20"></span> <a href="index.html#dispatchers" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Dispatchers return tables that describe an action you want to make. They
do not invoke any action immediately, and their contents are not
guaranteed to be stable at all. Their purpose is to be fed into
`hl.bind()` or `hl.dispatch()`.

### Parameter explanation<span id="parameter-explanation" class="hx:absolute hx:-mt-20"></span> <a href="index.html#parameter-explanation" class="subheading-anchor"
aria-label="Permalink for this section"></a>

| Param type | Description |
|----|----|
| `action` | `toggle`(default if no value given), `enable`/`on`, `disable`/`off` |

#### Window<span id="window" class="hx:absolute hx:-mt-20"></span> <a href="index.html#window" class="subheading-anchor"
aria-label="Permalink for this section"></a>

A window. Can be:

- window object
- regexes:
  - `class:...`
  - `initialclass:...`
  - `title:...`
  - `initialtitle:...`
  - `tag:...`
- exact selectors:
  - `pid:...`
  - `stableid:...`
  - `address:0x...`
- `activewindow`
- `floating`
- `tiled`

If no window is provided, the active window is used.

#### Workspace<span id="workspace" class="hx:absolute hx:-mt-20"></span> <a href="index.html#workspace" class="subheading-anchor"
aria-label="Permalink for this section"></a>

A workspace. Can be:

- workspace object
- workspace ID
- workspace selector, see [below](index.html#workspace-selectors)

#### Direction<span id="direction" class="hx:absolute hx:-mt-20"></span> <a href="index.html#direction" class="subheading-anchor"
aria-label="Permalink for this section"></a>

A simple direction. `l` / `r` / `u` / `d`

#### Monitor<span id="monitor" class="hx:absolute hx:-mt-20"></span> <a href="index.html#monitor" class="subheading-anchor"
aria-label="Permalink for this section"></a>

A monitor. Can be:

- monitor object
- monitor ID
- direction
- name
- `desc:` and description
- `current`
- relative: `+1` / `-2`

## Dispatchers<span id="dispatchers-1" class="hx:absolute hx:-mt-20"></span> <a href="index.html#dispatchers-1" class="subheading-anchor"
aria-label="Permalink for this section"></a>

### General<span id="general" class="hx:absolute hx:-mt-20"></span> <a href="index.html#general" class="subheading-anchor"
aria-label="Permalink for this section"></a>

`hl.dsp.` contains:

| method | description |
|----|----|
| `exec_cmd(cmd, rules?)` | execute a command. Rules can be a table of window rule effects to apply (see [below](index.html#executing-with-rules)). |
| `exec_raw(cmd)` | execute a raw command. While `exec_cmd` will do `sh -c`, this won’t. |
| `focus({ direction })` | move the focus in a direction |
| `focus({ monitor })` | move the focus to a monitor |
| `focus({ workspace, on_current_monitor? })` | move the focus to a workspace |
| `focus({ window })` | move the focus to a window |
| `focus({ urgent_or_last })` | move the focus to an urgent, or last window |
| `focus({ last })` | move the focus to the last window |
| `exit()` | quit Hyprland. It’s recommended to use `hyprshutdown` instead of this. |
| `submap(name)` | move to a submap |
| `pass({ window? })` | pass the shortcut to a window |
| `send_shortcut({ mods, key, window? })` | send a specific shortcut to a window |
| `send_key_state({ mods, key, state, window? })` | same as above, but you control `down` / `up` |
| `layout(message)` | send a layout message as a string |
| `dpms({ action?, monitor? })` | toggle monitors on/off (not physically, as in idle-screensaver.) |
| `event(string)` | send an event to socket2. |
| `global(string)` | activate a dbus global shortcut. See [Binds \> Global Shortcuts](https://wiki.hypr.land/Configuring/Basics/Binds#dbus-global-shortcuts) |
| `force_idle(seconds)` | sets elapsed time for all idle timers, ignoring idle inhibitors. Timers return to normal behavior upon the next activity. Do not use with a keybind directly. |
| `no_op()` | does nothing. Useful for conditional binds. |
| `force_renderer_reload()` | force reloads the renderer on all monitors. |

### Window<span id="window-1" class="hx:absolute hx:-mt-20"></span> <a href="index.html#window-1" class="subheading-anchor"
aria-label="Permalink for this section"></a>

`hl.dsp.window.` contains:

| method | description |
|----|----|
| `close({ window? })` | Send a graceful request to close the window. |
| `kill({ window? })` | Kill the process owning the window with a `SIGKILL`. |
| `signal({ signal, window? })` | Send a POSIX signal to the process owning the window. |
| `float({ action?, window? })` | set a window’s floating state. |
| `fullscreen({ mode?, action?, window? })` | set a window’s fullscreen state. `mode` can be “maximized” and “fullscreen”. `action` can be `toggle`/`set`/`unset` |
| `fullscreen_state({ internal, client, action?, window? })` | set a window’s fullscreen state with more precision. `action` can be `toggle`/`set`/`unset`. See [Fullscreenstate](index.html#fullscreenstate) |
| `pseudo({ action?, window? })` | set a window’s pseudotiling state. |
| `move({ direction, group_aware?, window? })` | move a window in a direction. `group_aware = true` will put windows in/out of groups alongside the given direction. |
| `move({ workspace, follow?, window? })` | move a window to a workspace |
| `move({ monitor, follow?, window? })` | move a window to a monitor |
| `move({ x, y, relative?, window? })` | move a window by / to a coord |
| `move({ into_group = direction, window? })` | move a window into a group in a direction |
| `move({ into_or_create_group = direction, window? })` | move a window into a group in a direction, or create a group if no group exists in that direction |
| `move({ out_of_group, window? })` | move a window out of a group. `true` for directionless, direction for a direction |
| `swap({ direction })` | swap the current window with another one in a given direction |
| `swap({ target })` | swap the current window with another one |
| `swap({ next })` | swap the current window with the next one |
| `swap({ prev })` | swap the current window with the previous one |
| `center({ window? })` | center the current window on screen |
| `cycle_next({ next?, tiled?, floating?, window? })` | focus the next window |
| `tag({ tag, window? })` | tag a window |
| `clear_tags({ window? })` | clear all tags from a window |
| `toggle_swallow()` | toggle all swallowed windows visible |
| `pin({ action?, window? })` | pin a window |
| `alter_zorder({ mode, window? })` | mode can be “top” or “bottom” |
| `set_prop({ prop, value, window? })` | set a window property |
| `deny_from_group({ action? })` | deny a window from entering a group |
| `drag()` | begin an interactive drag. To be used with mouse binds. |
| `resize()` | begin an interactive resize. To be used with mouse binds. |
| `resize({ keep_aspect_ratio })` | begin an interactive resize. To be used with mouse binds. Overrides window’s `keep_aspect_ratio` prop. |
| `resize({ x, y, relative?, window? })` | resize a window |

### Workspace<span id="workspace-1" class="hx:absolute hx:-mt-20"></span> <a href="index.html#workspace-1" class="subheading-anchor"
aria-label="Permalink for this section"></a>

`hl.dsp.workspace.` contains:

| method | description |
|----|----|
| `rename({ workspace, name? })` | rename a workspace |
| `move({ workspace?, monitor })` | move a workspace to a monitor |
| `swap_monitors({ monitor1, monitor2 })` | swap current workspaces of two monitors |
| `toggle_special(special_name)` | toggle a special workspace by name |

### Group<span id="group" class="hx:absolute hx:-mt-20"></span> <a href="index.html#group" class="subheading-anchor"
aria-label="Permalink for this section"></a>

`hl.dsp.group.` contains:

| method | description |
|----|----|
| `toggle({ window? })` | toggle a group |
| `next({ window? })` | switch to the next window in a group |
| `prev({ window? })` | switch to the previous window in a group |
| `active({ index, window? })` | switch to a window in a group, indexed |
| `move_window({ forward?, window? })` | move a window in the group order |
| `lock({ action?, window? })` | lock a group |
| `lock_active({ action? })` | lock the active group |

### Cursor<span id="cursor" class="hx:absolute hx:-mt-20"></span> <a href="index.html#cursor" class="subheading-anchor"
aria-label="Permalink for this section"></a>

`hl.dsp.cursor.` contains:

| method | description |
|----|----|
| `move_to_corner({ corner, window? })` | move the cursor to a given corner of the window. Corner is 0-3 |
| `move({ x, y })` | move the cursor to a given coordinate |

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

[uwsm](https://wiki.hypr.land/Useful-Utilities/Systemd-start) users
should avoid using `exit` dispatcher, or terminating Hyprland process
directly, as exiting Hyprland this way removes it from under its clients
and interferes with ordered shutdown sequence. Use `exec, uwsm stop` (or
<a href="https://github.com/Vladimir-csp/uwsm#how-to-stop"
target="_blank" rel="noopener">other variants</a>) which will gracefully
bring down graphical session (and login session bound to it, if any). If
you experience problems with units entering inconsistent states,
affecting subsequent sessions, use `exec, loginctl terminate-user ""`
instead (terminates all units of the user).

It’s also strongly advised to replace the `exit` dispatcher inside
`hyprland.lua` keybinds section accordingly.

</div>

</div>

</div>

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

It is NOT recommended to set DPMS or forceidle with a keybind directly,
as it might cause undefined behavior. Instead, consider something like

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.bind("...", function()
                 hl.timer(function()
                   hl.dispatch(hl.dsp.dpms({ action = "disable" }))
                 end, {timeout = 500, type = "oneshot"})
               end)
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

</div>

</div>

### Grouped (tabbed) windows<span id="grouped-tabbed-windows" class="hx:absolute hx:-mt-20"></span> <a href="index.html#grouped-tabbed-windows" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Hyprland allows you to make a group from the current active window with
the `hl.dsp.group.toggle()` bind dispatcher.

A group is like i3wm’s “tabbed” container. It takes the space of one
window, and you can toggle the windows within it.

You can lock a group with the `lock` dispatcher in order to stop new
windows from entering this group.

You can prevent a window from being added to a group or becoming a group
with the `window.deny_from_group` dispatcher.

## Workspace selectors<span id="workspace-selectors" class="hx:absolute hx:-mt-20"></span> <a href="index.html#workspace-selectors" class="subheading-anchor"
aria-label="Permalink for this section"></a>

You have nine choices:

- ID: e.g. `1`, `2`, or `3`

- Relative ID: e.g. `+1`, `-3` or `+100`

- workspace on monitor, relative with `+` or `-`, absolute with `~`:
  e.g. `m+1`, `m-2` or `m~3`

- workspace on monitor including empty workspaces, relative with `+` or
  `-`, absolute with `~`: e.g. `r+1` or `r~3`

- open workspace, relative with `+` or `-`, absolute with `~`: e.g.
  `e+1`, `e-10`, or `e~2`

- Name: e.g. `name:Web`, `name:Anime` or `name:Better anime`

- Previous workspace: `previous`, or `previous_per_monitor`

- First available empty workspace: `empty`, suffix with `m` to only
  search on monitor. and/or `n` to make it the *next* available empty
  workspace. e.g. `emptynm`

- Special Workspace: `special` or `special:name` for named special
  workspaces.

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-amber-200 hx:bg-amber-100 hx:text-amber-900 hx:dark:border-amber-200/30 hx:dark:bg-amber-900/30 hx:dark:text-amber-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMiA5djJtMCA0aC4wMW0tNi45MzggNGgxMy44NTZjMS41NC4wIDIuNTAyLTEuNjY3IDEuNzMyLTNMMTMuNzMyIDRjLS43Ny0xLjMzMy0yLjY5NC0xLjMzMy0zLjQ2NC4wTDMuMzQgMTZjLS43NyAxLjMzMy4xOTIgMyAxLjczMiAzeiIgLz48L3N2Zz4="
class="hx:inline-block hx:align-middle hx:mr-2" />Warning

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

Numerical workspaces (e.g. `1`, `2`, `13371337`) are allowed **ONLY**
between 1 and 2147483647 (inclusive).  
Neither `0` nor negative numbers are allowed.

</div>

</div>

</div>

## Special Workspace<span id="special-workspace" class="hx:absolute hx:-mt-20"></span> <a href="index.html#special-workspace" class="subheading-anchor"
aria-label="Permalink for this section"></a>

A special workspace is what is called a “scratchpad” in some other
places. A workspace that you can toggle on/off on any monitor.

<div class="hx:overflow-x-auto hx:mt-6 hx:flex hx:flex-col hx:rounded-lg hx:border hx:py-4 hx:px-4 hx:border-gray-200 hx:contrast-more:border-current hx:contrast-more:dark:border-current hx:border-blue-200 hx:bg-blue-100 hx:text-blue-900 hx:dark:border-blue-200/30 hx:dark:bg-blue-900/30 hx:dark:text-blue-200">

<img
src="data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjE2IiBjbGFzcz0iaHg6aW5saW5lLWJsb2NrIGh4OmFsaWduLW1pZGRsZSBoeDptci0yIiBmaWxsPSJub25lIiB2aWV3Ym94PSIwIDAgMjQgMjQiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiIGQ9Ik0xMyAxNmgtMXYtNGgtMW0xLTRoLjAxTTIxIDEyQTkgOSAwIDExMyAxMmE5IDkgMCAwMTE4IDB6IiAvPjwvc3ZnPg=="
class="hx:inline-block hx:align-middle hx:mr-2" />Note

<div class="hx:w-full hx:min-w-0 hx:leading-7">

<div class="hx:mt-6 hx:leading-7 hx:first:mt-0">

You can define multiple named special workspaces, but the amount of
those is limited to 97 at a time.

</div>

</div>

</div>

For example, to move a window to a named special workspace you can use
the following syntax:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.bind("SUPER + C", hl.dsp.window.move({ workspace = "special:magic" }))
-- To see the hidden window and workspace you can use: 
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("magic"))
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

## Executing with rules<span id="executing-with-rules" class="hx:absolute hx:-mt-20"></span> <a href="index.html#executing-with-rules" class="subheading-anchor"
aria-label="Permalink for this section"></a>

The `exec_cmd` dispatcher supports adding rules. Please note some
windows might work better, some worse. It records the PID of the spawned
process and uses that. For example, if your process forks and then the
fork opens a window, this will not work.

Example:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.bind("SUPER + E", hl.dsp.exec_cmd("kitty", { float = true, move = {0, 0} }))
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

## set_prop<span id="set_prop" class="hx:absolute hx:-mt-20"></span> <a href="index.html#set_prop" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Props are any of the *dynamic effects* of [Window
Rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules#dynamic-effects).

For example:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
{ prop = "no_anim", value = "1" }
{ prop = "no_anim", value = "1", window = "class:abc" }
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

Some props are expanded from their window rule parents which take
multiple arguments:

- `border_color` -\> `active_border_color`, `inactive_border_color`
- `opacity` -\> `opacity`, `opacity_inactive`, `opacity_fullscreen`,
  `opacity_override`, `opacity_inactive_override`,
  `opacity_fullscreen_override`

## Fullscreenstate<span id="fullscreenstate" class="hx:absolute hx:-mt-20"></span> <a href="index.html#fullscreenstate" class="subheading-anchor"
aria-label="Permalink for this section"></a>

The `fullscreen_state` dispatcher decouples the state that Hyprland
maintains for a window from the fullscreen state that is communicated to
the client.

`internal` is a reference to the state maintained by Hyprland.

`client` is a reference to the state that the application receives.

| Value | State | Description |
|----|----|----|
| -1 | Current | Maintains the current fullscreen state. |
| 0 | None | Window allocates the space defined by the current layout. |
| 1 | Maximize | Window takes up the entire working space, keeping the margins. |
| 2 | Fullscreen | Window takes up the entire screen. |
| 3 | Maximize and Fullscreen | The state of a fullscreened maximized window. Works the same as fullscreen. |

For example:

`{internal = 2, client = 0}` Fullscreens the application and keeps the
client in non-fullscreen mode.

This can be used to prevent Chromium-based browsers from going into
presentation mode when they detect they have been fullscreened.

`{internal = 0, client = 2}` Keeps the window non-fullscreen, but the
client goes into fullscreen mode within the window.

</div>

<div class="hx:mt-12 hx:mb-8 hx:block hx:text-xs hx:text-gray-500 hx:ltr:text-right hx:rtl:text-left hx:dark:text-gray-400">

Last updated on July 3, 2026

</div>

<div class="hx:mb-8 hx:flex hx:items-center hx:border-t hx:pt-8 hx:border-gray-200 hx:dark:border-neutral-800 hx:contrast-more:border-neutral-400 hx:dark:contrast-more:border-neutral-400 hx:print:hidden">

<a href="../Binds/index.html"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:pr-4 hx:rtl:pl-4"
title="Binds"><img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpsdHI6cm90YXRlLTE4MCIgZmlsbD0ibm9uZSIgdmlld2JveD0iMCAwIDI0IDI0IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBhcmlhLWhpZGRlbj0idHJ1ZSI+PHBhdGggc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBkPSJNOSA1bDcgNy03IDciIC8+PC9zdmc+"
class="hx:inline hx:h-5 hx:shrink-0 hx:ltr:rotate-180" />Binds</a><a href="../Window-Rules/index.html"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:ml-auto hx:ltr:pl-4 hx:ltr:text-right hx:rtl:mr-auto hx:rtl:pr-4 hx:rtl:text-left"
title="Window Rules">Window Rules<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpydGw6LXJvdGF0ZS0xODAiIGZpbGw9Im5vbmUiIHZpZXdib3g9IjAgMCAyNCAyNCIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgYXJpYS1oaWRkZW49InRydWUiPjxwYXRoIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIgZD0iTTkgNWw3IDctNyA3IiAvPjwvc3ZnPg=="
class="hx:inline hx:h-5 hx:shrink-0 hx:rtl:-rotate-180" /></a>

</div>

</div>
