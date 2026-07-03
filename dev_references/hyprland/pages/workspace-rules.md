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

Workspace Rules

</div>

</div>

<div class="content">

<div class="hx:flex hx:flex-col hx:sm:flex-row hx:items-start hx:sm:items-center hx:sm:justify-between hx:gap-4 hx:mb-4">

# Workspace Rules

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

You can set workspace rules to achieve workspace-specific behaviors. For
instance, you can define a workspace where all windows are drawn without
borders or gaps.

For layout-specific rules, see the specific layout page. For example:
[Master Layout-\>Workspace
Rules](https://wiki.hypr.land/Configuring/Layouts/Master-Layout#workspace-rules).

## Syntax<span id="syntax" class="hx:absolute hx:-mt-20"></span> <a href="index.html#syntax" class="subheading-anchor"
aria-label="Permalink for this section"></a>

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.workspace_rule(workspace, rule1, rule2, ...)
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

- WORKSPACE is a valid workspace identifier (see
  [Dispatchers-\>Workspaces](https://wiki.hypr.land/Configuring/Basics/Dispatchers#workspace)).
  This field is mandatory. This *can be* a workspace selector, but
  please note workspace selectors can only match *existing* workspaces.
- RULES is one (or more) rule(s) as described here in
  [rules](index.html#rules).

### Workspace selectors<span id="workspace-selectors" class="hx:absolute hx:-mt-20"></span> <a href="index.html#workspace-selectors" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Workspaces that have already been created can be targeted by workspace
selectors, e.g. `r[2-4] w[t1]`.

Selectors have props separated by a space. No spaces are allowed inside
props themselves.

Props:

- `r[A-B]` - ID range from A to B inclusive
- `s[bool]` - Whether the workspace is special or not
- `n[bool]`, `n[s:string]`, `n[e:string]` - named actions. `n[bool]` -\>
  whether a workspace is a named workspace, `s` and `e` are starts and
  ends with respectively
- `m[monitor]` - Monitor selector
- `w[(flags)A-B]`, `w[(flags)X]` - Prop for window counts on the
  workspace. A-B is an inclusive range, X is a specific number. Flags
  can be omitted. It can be `t` for tiled-only, `f` for floating-only,
  `g` to count groups instead of windows, `v` to count only visible
  windows, and `p` to count only pinned windows.
- `f[-1]`, `f[0]`, `f[1]`, `f[2]` - fullscreen state of the workspace.
  `-1`: no fullscreen, `0`: fullscreen, `1`: maximized, `2`, fullscreen
  without fullscreen state sent to the window.

## Rules<span id="rules" class="hx:absolute hx:-mt-20"></span> <a href="index.html#rules" class="subheading-anchor"
aria-label="Permalink for this section"></a>

| Rule | Description | type |
|----|----|----|
| monitor | Binds a workspace to a monitor. See [syntax](index.html#syntax) and [Monitors](https://wiki.hypr.land/Configuring/Basics/Monitors). | string |
| default | Whether this workspace should be the default workspace for the given monitor | bool |
| gaps_in | Set the gaps between windows (equivalent to [General-\>gaps_in](https://wiki.hypr.land/Configuring/Basics/Variables#general)) | css_gaps |
| gaps_out | Set the gaps between windows and monitor edges (equivalent to [General-\>gaps_out](https://wiki.hypr.land/Configuring/Basics/Variables#general)) | css_gaps |
| float_gaps | Set the gaps for floating windows (equivalent to [General-\>float_gaps](https://wiki.hypr.land/Configuring/Basics/Variables#general)) | css_gaps |
| border_size | Set the border size around windows (equivalent to [General-\>border_size](https://wiki.hypr.land/Configuring/Basics/Variables#general)) | int |
| no_border | Whether to disable borders | bool |
| no_shadow | Whether to disable shadows | bool |
| no_rounding | Whether to disable rounded windows | bool |
| decorate | Whether to draw window decorations or not | bool |
| persistent | Keep this workspace alive even if empty and inactive | bool |
| on_created_empty | A command to be executed once a workspace is created empty (i.e. not created by moving a window to it). See the [command syntax](https://wiki.hypr.land/Configuring/Basics/Dispatchers#executing-with-rules) | string |
| default_name | A default name for the workspace. | string |
| layout | The layout to use for this workspace. | string |
| animation | The animation style to use for this workspace. | string |
| layout_opts | A table of layout-specific options for this workspace. Keys and values depend on the layout. | table |

## Examples<span id="examples" class="hx:absolute hx:-mt-20"></span> <a href="index.html#examples" class="subheading-anchor"
aria-label="Permalink for this section"></a>

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.workspace_rule({ workspace = "3", no_rounding = true, decorate = false })
hl.workspace_rule({ workspace = "name:coding", no_rounding = true, decorate = false, gaps_in = 0, gaps_out = 0, no_border = true, monitor = "DP-1" })
hl.workspace_rule({ workspace = "8", border_size = 8 })
hl.workspace_rule({ workspace = "name:Hello", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "name:gaming", monitor = "desc:Chimei Innolux Corporation 0x150C", default = true })
hl.workspace_rule({ workspace = "5", on_created_empty = "[float] firefox" })
hl.workspace_rule({ workspace = "special:scratchpad", on_created_empty = "foot" })
hl.workspace_rule({ workspace = "15", animation = "slidevert", default_name = "slider" })
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

### Smart gaps<span id="smart-gaps" class="hx:absolute hx:-mt-20"></span> <a href="index.html#smart-gaps" class="subheading-anchor"
aria-label="Permalink for this section"></a>

To replicate “smart gaps” / “no gaps when only” from other
WMs/Compositors, use this bad boy:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, rounding = 0 })
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

#### Smart gaps (ignoring special workspaces)<span id="smart-gaps-ignoring-special-workspaces" class="hx:absolute hx:-mt-20"></span> <a href="index.html#smart-gaps-ignoring-special-workspaces"
class="subheading-anchor" aria-label="Permalink for this section"></a>

You can combine workspace selectors for more fine-grained control, for
example, to ignore special workspaces:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" }, rounding = 0 })
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

### Per-workspace layouts<span id="per-workspace-layouts" class="hx:absolute hx:-mt-20"></span> <a href="index.html#per-workspace-layouts" class="subheading-anchor"
aria-label="Permalink for this section"></a>

Use workspace rules to set per-workspace layouts:

<div class="hextra-code-block hx:relative hx:mt-6 hx:first:mt-0 hx:group/code">

<div>

<div class="highlight">

``` chroma
hl.workspace_rule({ workspace = "2", layout = "scrolling" })
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

<div class="hx:mb-8 hx:flex hx:items-center hx:border-t hx:pt-8 hx:border-gray-200 hx:dark:border-neutral-800 hx:contrast-more:border-neutral-400 hx:dark:contrast-more:border-neutral-400 hx:print:hidden">

<a href="../Window-Rules/index.html"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:pr-4 hx:rtl:pl-4"
title="Window Rules"><img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpsdHI6cm90YXRlLTE4MCIgZmlsbD0ibm9uZSIgdmlld2JveD0iMCAwIDI0IDI0IiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZT0iY3VycmVudENvbG9yIiBhcmlhLWhpZGRlbj0idHJ1ZSI+PHBhdGggc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBkPSJNOSA1bDcgNy03IDciIC8+PC9zdmc+"
class="hx:inline hx:h-5 hx:shrink-0 hx:ltr:rotate-180" />Window
Rules</a><a href="https://wiki.hypr.land/Configuring/Basics/Autostart/"
class="hx:flex hx:max-w-[50%] hx:items-center hx:gap-1 hx:py-4 hx:text-base hx:font-medium hx:text-gray-600 hx:transition-colors [word-break:break-word] hx:hover:text-primary-600 hx:dark:text-gray-300 hx:md:text-lg hx:ltr:ml-auto hx:ltr:pl-4 hx:ltr:text-right hx:rtl:mr-auto hx:rtl:pr-4 hx:rtl:text-left"
title="Autostart">Autostart<img
src="data:image/svg+xml;base64,PHN2ZyBjbGFzcz0iaHg6aW5saW5lIGh4OmgtNSBoeDpzaHJpbmstMCBoeDpydGw6LXJvdGF0ZS0xODAiIGZpbGw9Im5vbmUiIHZpZXdib3g9IjAgMCAyNCAyNCIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2U9ImN1cnJlbnRDb2xvciIgYXJpYS1oaWRkZW49InRydWUiPjxwYXRoIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIgZD0iTTkgNWw3IDctNyA3IiAvPjwvc3ZnPg=="
class="hx:inline hx:h-5 hx:shrink-0 hx:rtl:-rotate-180" /></a>

</div>

</div>
