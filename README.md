<!-- space between -->
<h1>
  omarchy-zellij-theme &nbsp;&nbsp; <img src="https://raw.githubusercontent.com/skvggor/omarchy-zellij-theme/refs/heads/develop/assets/star.svg" alt="Star" height="30" style="vertical-align: middle;" />
</h1>

Syncs your [Zellij](https://zellij.dev/) theme with your [Omarchy](https://omarchy.org/) system theme automatically.

<p align="center">
  
https://github.com/user-attachments/assets/0be5f3c9-fbba-479c-9f52-bd312aed5a8c

</p>

Every time you run `omarchy theme set`, Zellij picks up the same color palette in real time.

## How it works

Omarchy's template engine processes `zellij.kdl.tpl` using the active theme's `colors.toml`, generating a KDL theme block in `~/.local/state/omarchy/current/theme/zellij.kdl`. A `theme-set` hook converts the output from comma-separated RGB (`R,G,B`) to space-separated (`R G B`) and injects the `themes {}` block directly into `~/.config/zellij/config.kdl`. Since Zellij watches its config file, existing sessions hot-reload the new theme instantly.

The hook also re-asserts `theme "omarchy"` on every run (and keeps `theme_dark`/`theme_light` disabled, since they override it): Zellij rewrites `config.kdl` itself, so a `zellij options` change or an upgrade can drop the selection, after which Zellij silently falls back to its built-in theme and the UI stops following Omarchy. It writes the config atomically (temp file plus rename, following a symlinked config), so the watcher never reads a half-written file, and it refuses to write a config Zellij cannot parse.

```
colors.toml ──> omarchy theme set/refresh ──> zellij.kdl (R,G,B)
                                              ~/.local/state/omarchy/current/theme/
                                                     │
                                               theme-set hook
                                            (sed R,G,B -> R G B)
                                                     │
                                                     ▼
                                      ~/.config/zellij/config.kdl
                                      (inline themes {} block)
                                                     │
                                                     ▼
                                          Zellij hot-reloads ✓
```

### Color mapping

| Zellij component         | Omarchy color                                            |
| ------------------------ | -------------------------------------------------------- |
| Text base                | `foreground`                                             |
| Backgrounds              | `background`, `selection` (selected)                     |
| Selected text            | `selection_foreground` on `selection`                    |
| Ribbon selected          | `accent` bg, `background` text                           |
| Ribbon unselected        | `color7` bg, `background` text                           |
| Frame selected           | `accent`                                                 |
| Frame unselected         | `color8`                                                 |
| Frame highlight          | `color3`                                                 |
| Emphases                 | `color1`..`color5` distributed across emphasis_0..3      |
| Exit success / error     | `color2` / `color1`                                      |

## Install

```bash
git clone https://github.com/skvggor/omarchy-zellij-theme.git
cd omarchy-zellij-theme
./install.sh
```

The installer:

1. Symlinks `zellij.kdl.tpl` into `~/.config/omarchy/themed/`
2. Installs the `theme-set` hook into `~/.config/omarchy/hooks/theme-set.d/` (migrating legacy pre-Omarchy Quattro hooks)
3. Selects `theme "omarchy"` in `~/.config/zellij/config.kdl`, disabling any competing `theme`/`theme_dark`/`theme_light` selectors (creates a timestamped backup first)
4. Cleans up old theme file from previous approach if present
5. Installs the `zellij-launcher` script into `~/.local/bin/`, aliases `zellij` to it in `~/.bashrc`/`~/.zshrc`, and points the `zellij.desktop` entry in `~/.local/share/applications/` at it (so launches from the Omarchy menu also land in `alila`)
6. Generates and injects the current theme inline into `config.kdl`

It is safe to re-run -- the script is idempotent.

## Upgrading to Omarchy Quattro

Omarchy Quattro moved the theme state to `~/.local/state/omarchy/current/` and changed the hook layout. If you installed a previous version of this theme, update and re-run the installer:

```bash
git pull
./install.sh
```

The installer migrates everything automatically:

- Moves the hook from the legacy single-file `~/.config/omarchy/hooks/theme-set` to `~/.config/omarchy/hooks/theme-set.d/omarchy-zellij-theme` (a custom hook of yours is preserved -- only the appended Zellij integration is removed)
- Re-reads theme state from `~/.local/state/omarchy/current/`
- Re-injects the current theme into `config.kdl`, replacing any stale theme block

Save your work first: the last install step runs `omarchy theme refresh`, which restarts the terminal as part of applying the theme.

## Uninstall

```bash
./uninstall.sh
```

This reverts everything:

1. Removes the template symlink from `~/.config/omarchy/themed/`
2. Removes the hook from `~/.config/omarchy/hooks/theme-set.d/` (and any legacy pre-Omarchy Quattro integration)
3. Comments out `theme "omarchy"` in `~/.config/zellij/config.kdl`
4. Removes the inline `themes {}` block from `config.kdl`
5. Cleans up old theme file if present
6. Removes the `zellij-launcher` script, its shell alias, and the `zellij.desktop` override

Zellij returns to its default theme on the next session.

## Files

| File              | Purpose                                                              |
| ----------------- | -------------------------------------------------------------------- |
| `zellij.kdl.tpl`  | Zellij theme template using `{{ key_rgb }}` placeholders             |
| `theme-set`        | Hook script -- converts RGB format and injects theme into config.kdl |
| `theme-notify`     | Floating pane notification shown on theme change                     |
| `zellij-launcher`  | Starts/attaches the fixed `alila` session on a bare `zellij`         |
| `install.sh`       | Installer (symlink, hook, config, initial apply)                     |
| `uninstall.sh`     | Uninstaller (reverts all changes)                                    |

## Requirements

- [Omarchy](https://omarchy.org/) Quattro (4.0) or later, including 4.5 (Quattro RS), with the template/hook system (`omarchy theme set`, `omarchy theme refresh`)
- [Zellij](https://zellij.dev/) with config at `~/.config/zellij/config.kdl`

## Usage

After installing, just use Omarchy as usual:

```bash
omarchy theme set tokyo-night   # Zellij theme updates instantly (all sessions)
omarchy theme set catppuccin    # same
```

All Zellij sessions -- including ones already running -- pick up the new theme in real time.

## Default session

After installing, a bare `zellij` always lands in the fixed `alila` session: it is created on the first launch and attached to on later launches.

```bash
zellij               # create or attach to "alila"
zellij list-sessions # arguments and subcommands pass through unchanged
```

The installer adds an alias for `~/.local/bin/zellij-launcher` to `~/.bashrc` and `~/.zshrc`, so this applies to interactive shells. GUI launches do not read shell aliases, so the installer also drops a `zellij.desktop` in `~/.local/share/applications/` whose `Exec` calls the launcher; that entry shadows the system one in the Omarchy menu. Inside an existing Zellij session, Zellij's normal behaviour is preserved. Set `ZELLIJ_DEFAULT_SESSION` to use a different session name.
