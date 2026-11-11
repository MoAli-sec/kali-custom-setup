# kali-custom-setup

A fully scripted, from-scratch Kali Linux build for one machine doing three
jobs: daily-driver desktop, bug bounty hunting, and CTF work.

Everything here is meant to be **re-runnable** — wipe the machine, clone
this repo, run one script, and get back to a working environment instead of
re-installing tools from memory one at a time.

## Why this exists

My previous Kali setup was hand-configured over time with no record of what
I'd installed or why, so when it broke I had no way to rebuild it quickly.
This repo is that record, turned into automation: a modular install script,
dotfiles, and notes, so the whole environment is reproducible and versioned.

## Hardware / environment this targets

- HP ZBook 15 G3 (i7-6700HQ, 16GB RAM), dual-boot **Kali Linux** + Windows 10
- Desktop environment: **GNOME**
- Shell: **zsh** (oh-my-zsh + Powerlevel10k)
- Use cases: general desktop use, bug bounty / web app testing, CTF
  (pwn, forensics, crypto, reversing)

The scripts assume Kali/Debian (`apt`), but most of the dotfiles are
portable to any Linux distro running zsh.

## Structure

```
kali-custom-setup/
├── install.sh                  # entry point — interactive menu or flags
├── gnome-tweaks.sh              # standalone GNOME config tool (own backup/revert)
├── theme-pack.sh                # Tokyo Night aesthetic pack (own backup/revert)
├── sync-burn-color.sh            # matches Burn My Windows' fire color to your wallpaper
├── revert.sh                    # one-stop undo for GNOME + dotfiles + theme-pack + burn-color
├── restore.sh                   # same as revert.sh, under the name people look for
├── scripts/
│   ├── 01-system-update.sh
│   ├── 02-general-tools.sh     # daily-driver CLI/desktop tools
│   ├── 03-bugbounty-tools.sh   # recon + web app testing toolkit
│   ├── 04-ctf-tools.sh         # pwn / reversing / forensics / crypto
│   ├── 05-zsh-setup.sh         # oh-my-zsh, powerlevel10k, plugins
│   ├── 06-gnome-setup.sh       # installs GNOME helper apps, then calls gnome-tweaks.sh
│   └── 07-dotfiles-setup.sh    # symlinks dotfiles into $HOME (backs up + can revert)
├── dotfiles/
│   ├── zsh/                    # .zshrc, aliases, functions, exports
│   ├── tmux/                   # .tmux.conf
│   ├── git/                    # .gitconfig template
│   └── gnome/                  # recommended extensions list
└── docs/
    └── SETUP_GUIDE.md           # detailed notes + reset instructions
```

## Quick start

```bash
git clone https://github.com/MoAli-sec/kali-custom-setup.git
cd kali-custom-setup
chmod +x install.sh revert.sh restore.sh gnome-tweaks.sh theme-pack.sh sync-burn-color.sh scripts/*.sh
./install.sh
```

Running `./install.sh` with no arguments opens an interactive menu. To
automate a specific piece instead:

```bash
./install.sh --all          # run every module in order
./install.sh --general      # daily-driver tools only
./install.sh --bugbounty    # recon + web app testing toolkit only
./install.sh --ctf          # pwn/reversing/forensics/crypto toolkit only
./install.sh --shell        # zsh + oh-my-zsh + plugins only (same as --zsh)
./install.sh --gnome        # GNOME tweaks only
./install.sh --theme        # theme pack: wallpaper, themes, terminal colors (same as --theme-pack)
./install.sh --theme --ember  # ...in the red/orange palette instead of Tokyo Night
./install.sh --dotfiles     # symlink dotfiles only
./install.sh --revert       # undo GNOME/dotfiles changes (see below)
./install.sh --dry-run      # preview only — see "Previewing changes" below
```

The modules, and what each one touches:

| Module | Flag | What it does |
|---|---|---|
| shell | `--shell` | zsh, oh-my-zsh, Powerlevel10k, autosuggestions/syntax-highlighting |
| gnome | `--gnome` | GNOME helper apps (Tweaks, Extension Manager, GSConnect) + safe settings |
| theme | `--theme` | wallpaper, GTK/icon/cursor theme, terminal colors; Burn My Windows, fastfetch and Conky via `theme-pack.sh --animations/--banner/--overlay` |
| bugbounty | `--bugbounty` | subfinder, httpx, nuclei, naabu, katana, ffuf, dalfox, gobuster, nmap, sqlmap, Burp... |
| dotfiles | `--dotfiles` | symlinks `.zshrc`, `.tmux.conf`, `.gitconfig` (backs up what's there first) |
| general / ctf | `--general`, `--ctf` | daily-driver CLI tools / pwn + forensics + crypto toolkit |

`--all` runs the install modules in order. The theme module is deliberately
**not** part of `--all` — it changes how your desktop looks, so it's opt-in.

## Try it in a fresh Kali VM

The safest way to see what this does is in a throwaway VM, where a wrong turn
costs you a snapshot restore instead of your daily setup.

1. **Get a Kali VM.** Download one of the prebuilt VM images (VirtualBox,
   VMware or QEMU) from kali.org. 4 GB RAM, 2 CPUs and ~40 GB disk is a
   comfortable size. Log in as the default non-root user (`kali` in the
   official images) — `install.sh` refuses to run as root on purpose.
2. **Make sure you have a GNOME session.** Kali's default desktop is Xfce, and
   the GNOME and theme modules need GNOME. If you didn't choose it at install
   time: `sudo apt install -y kali-desktop-gnome`, log out, and pick the GNOME
   session from the login screen's session selector. (Skip this and the
   `--shell` and `--bugbounty` modules still work fine on Xfce.)
3. **Take a snapshot** named something like `clean`. Everything below can
   then be undone by restoring it.
4. **Get the repo and preview before changing anything:**
   ```bash
   git clone https://github.com/MoAli-sec/kali-custom-setup.git
   cd kali-custom-setup
   chmod +x install.sh revert.sh restore.sh gnome-tweaks.sh theme-pack.sh sync-burn-color.sh scripts/*.sh
   ./install.sh --dry-run --all              # which modules would run
   ./gnome-tweaks.sh --all --dry-run         # every setting: current -> new
   ./theme-pack.sh --ember --all --dry-run   # every step of the theme pack
   ```
5. **Run one module at a time**, so you can see what each one does:
   ```bash
   ./install.sh --shell        # then open a new terminal
   ./install.sh --dotfiles
   ./install.sh --gnome
   ./install.sh --theme --ember
   ./install.sh --bugbounty    # slowest: builds Go tools; plan for a while
   ```
6. **Run the same commands a second time.** Nothing should break or pile up
   (see "Safe to run twice" below).
7. **Log out and back in** (or Alt+F2 → `r` on X11) so GNOME Shell picks up the
   extensions. Burn My Windows looks best with graphics acceleration; in a VM
   without it the animation can be choppy or skipped — that's the VM, not the
   script.
8. **Undo it:** `./restore.sh` (same as `./revert.sh`) opens a menu, or
   `./restore.sh --all`. Then check that your original dotfiles and settings
   are back. If you want to be extra sure nothing outside the repo's own
   settings was touched, compare the enabled extensions before and after:
   ```bash
   gnome-extensions list --enabled | sort > /tmp/before.txt   # before step 5
   gnome-extensions list --enabled | sort > /tmp/after.txt    # after step 8
   diff /tmp/before.txt /tmp/after.txt && echo "unchanged"
   ```
9. **Done experimenting?** Restore the `clean` snapshot.

## Safe to run twice

Running any module again on a machine that already has it should change
nothing and break nothing:

- **Installs** check before installing (`dpkg -s`, `command -v`, "is this
  directory already there?"), so a second run skips what's already in place.
  A few steps always re-run because repeating them is harmless: `apt update`,
  the nuclei template update, and `pip install` inside the pwn venv.
- **Dotfiles:** an existing symlink is left alone, so a second run neither
  creates another backup nor touches files that are already linked.
- **Backups chain.** If you run a setup script twice without reverting in
  between, the second run keeps the *original* values from the first run, so
  one revert still takes you back to how things were before the first run —
  not to a half-themed middle state. Once you revert, the next run starts a
  fresh chain, and reverting the same backup again says "already reverted"
  and does nothing.
- **Shell config:** `typeset -U path` keeps `PATH` from growing each time
  `.zshrc` is sourced or `exec zsh` is run.

How this was checked: `gnome-tweaks.sh`, `theme-pack.sh`, `sync-burn-color.sh`
and the dotfiles script were each run twice against a real dconf database,
reverted once, and compared to the original — including with your own
pre-existing fastfetch/conky configs in place, with the palette changed
between runs, and with a revert followed by a new run. The `apt`-based modules
(`--general`, `--bugbounty`, `--ctf`, `--shell`) rely on the check-first guards
above; running them twice in your VM (step 6) is the real test of those.

Two things a revert deliberately does **not** undo: packages installed with
`apt`/`go install`/`pip` (auto-uninstalling can remove things other software
depends on), and the default-shell change from `chsh` in the `--shell` module
(set it back with `chsh -s /bin/bash`).

## Just want the GNOME tweaks, not the whole repo?

`gnome-tweaks.sh` at the repo root is fully standalone — no dependency on
the rest of this repo. Grab that one file and run it on its own:

```bash
chmod +x gnome-tweaks.sh
./gnome-tweaks.sh              # safe tweaks only (see below) — backs up first
./gnome-tweaks.sh --dark-mode  # also switch to dark mode (opt-in)
./gnome-tweaks.sh --dock       # also apply opinionated Dash to Dock settings (opt-in)
./gnome-tweaks.sh --font       # also install + set Fira Code as the terminal font (opt-in)
./gnome-tweaks.sh --all        # safe tweaks + dark mode + dock + font
./gnome-tweaks.sh --dry-run    # preview: each setting's current -> new value, changes nothing
./gnome-tweaks.sh --revert     # undo — restore the most recent backup
```

By default it only changes low-risk things (idle/lock timing, clock
display, a couple of window-manager details). It does **not** touch dark
mode/theme, Dash to Dock, or your terminal font unless you pass
`--dark-mode`, `--dock`, or `--font` — those are the changes most likely
to visibly alter your desktop in a way you didn't ask for, so they stay
opt-in. (`--font` is also the only one of these that needs `sudo`, since
it installs a font package.) Every run backs up the *specific* settings
it's about to change first, so `--revert` puts back exactly those —
nothing broader, so it can't touch something unrelated you already had
configured (like whether some other extension is enabled).

## Want an actual aesthetic, not just dark mode?

`theme-pack.sh` at the repo root builds a full look across GTK theme, icon
theme, cursor theme, generated wallpaper, and — critically — the
**terminal's actual color palette** (a GTK theme only changes window
chrome, not the colors your text renders in, so this is easy to miss and
easy to end up with a terminal that looks unchanged).

Two palettes to choose from:

```bash
chmod +x theme-pack.sh
./theme-pack.sh              # core suite, Tokyo Night palette (dark blue/purple)
./theme-pack.sh --ember      # core suite, ember palette instead (dark red/orange/amber)
./theme-pack.sh --banner     # + fastfetch banner on new terminals
./theme-pack.sh --animations # + Burn My Windows animated window close effects
./theme-pack.sh --overlay    # + Conky live CPU/RAM/network stats on the desktop
./theme-pack.sh --all        # everything above (combine with --ember for the ember version)
./theme-pack.sh --dry-run    # preview every step + each setting's current -> new value, changes nothing
./theme-pack.sh --revert     # undo — restores settings AND removes what it added
```

Every piece is the real upstream project, installed the way its own
maintainers document — not a hand-copied zip:

- **GTK theme**: [Tokyonight-GTK-Theme](https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme)
  (`-t default` for Tokyo Night, `-t orange` for ember)
- **Icons**: [Tela-circle-icon-theme](https://github.com/vinceliuice/Tela-circle-icon-theme)
  (purple or orange, dark variant)
- **Cursor**: [Bibata_Cursor](https://github.com/ful1e5/Bibata_Cursor) — Modern Ice, or Modern Amber for ember
- **Terminal colors**: GNOME Terminal's own profile schema
  (`org.gnome.Terminal.Legacy.Profile`) — background, foreground, and the
  full 16-color ANSI palette, hand-picked to match each theme while
  staying readable (diffs, syntax highlighting, etc. still need distinct
  hues even in a warm-toned palette)
- **Banner**: [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- **Animations**: [Burn My Windows](https://github.com/Schneegans/Burn-My-Windows),
  installed via the official `gnome-extensions` CLI — its own README
  explicitly warns against hand-copying files into the extensions folder,
  which is exactly what broke Dash to Dock in an earlier version of this repo.
- **Overlay**: Conky — a standalone app, not a GNOME Shell extension, so it
  can't fall into that same "installed but never enabled" trap.

It shares a backup store with `gnome-tweaks.sh`, so `--revert` restores your
GNOME settings from before *and* removes every theme/config file/extension
it added — verified by actually running the full install → revert cycle
end to end for both palettes, not just reasoned about.

## Keeping the fire animation color matched to your wallpaper

`sync-burn-color.sh` at the repo root analyzes your *current* wallpaper —
any wallpaper, not just one from this repo — finds its most common vivid
color, and recolors Burn My Windows' fire effect to match, using the same
brightness/alpha shape as its own default gradient so it still reads as
"fire," just in a different hue.

```bash
chmod +x sync-burn-color.sh
./sync-burn-color.sh              # detect + apply
./sync-burn-color.sh --dry-run    # preview the 5 fire colors it would set, writes nothing
./sync-burn-color.sh --revert     # undo — restores the previous fire colors
```

`theme-pack.sh --animations` calls this automatically after installing Burn
My Windows, so a fresh run already matches. Run it again yourself any time
you change your wallpaper afterward and want the animation to catch up.

Detects the extension via `gnome-extensions list` (and writes colors via
`dconf` directly) rather than through `gsettings` schema lookup — an
extension's schema often isn't visible to the plain `gsettings` CLI at all,
only to its own internal code, so relying on that would wrongly report
"not installed" even when it is.

## Previewing changes (`--dry-run`)

Every script that changes your desktop can show you what it *would* do first:

```bash
./gnome-tweaks.sh --all --dry-run          # each setting: current value  ->  new value
./theme-pack.sh --ember --all --dry-run    # every install step + each setting's current -> new
./sync-burn-color.sh --dry-run             # the 5 fire colors it would write
./install.sh --dry-run --all               # modules that would run + the GNOME setting changes
```

A dry run installs nothing, downloads nothing, writes no files, creates no
backup, and changes no settings. `--dry-run` also works on the undo side —
`./gnome-tweaks.sh --revert --dry-run` (same for `theme-pack.sh` and
`sync-burn-color.sh`) lists exactly which settings would be restored and,
for theme-pack, which files it would delete, before you confirm anything.

How this was checked rather than assumed: each dry run was executed against
a real dconf database with `sudo`/`apt`/`git`/`curl`/`gnome-extensions
install|enable` replaced by call loggers. Afterward the dconf database,
`$HOME`, and the repo were identical to before, and none of those commands
had been called.

One limit: for the package-install modules (`01`–`05`), `install.sh
--dry-run` only lists which step would run — it doesn't enumerate individual
packages. For the GNOME settings and `theme-pack.sh`, it shows exact values.

## Backups & undo

Nothing here overwrites your existing setup silently, and nothing reverts
more than it changed:

- **GNOME settings** — before changing anything, each script (`gnome-tweaks.sh`,
  `theme-pack.sh`, `sync-burn-color.sh`) records the *current* value of only
  the specific keys it's about to touch, to
  `~/.kali-custom-setup-backups/gnome/<timestamp>/settings.tsv`.
  `--revert` restores exactly those keys and nothing else — it never resets
  or reloads your whole GNOME settings tree, so it can't disable an
  unrelated extension you already had enabled, or touch anything these
  scripts didn't themselves set. (An earlier version did a wholesale
  `dconf reset` + reload on revert; that could revert things it never
  touched and risked destabilizing an active session by wiping a huge
  swath of live settings at once — confirmed and fixed by testing against
  a real dconf database, not just reasoning about it.)
- **Dotfiles** — `07-dotfiles-setup.sh` moves (not deletes) any dotfile it
  would overwrite into `~/.kali-custom-setup-backups/dotfiles/<timestamp>/`,
  with a manifest recording where each one came from.
  `./scripts/07-dotfiles-setup.sh --revert` puts everything back and
  removes the symlinks — including cleanly removing any file that didn't
  exist before (no phantom backups for those).
- **Config files theme-pack writes** (fastfetch, Conky): if you already had
  one, it's copied into the backup *before* being overwritten, and `--revert`
  puts your own file back (a file that didn't exist before is simply removed).
- **One-stop undo** — `./revert.sh` / `./restore.sh` (or `./install.sh --revert`) gives you
  a menu to revert GNOME, dotfiles, theme-pack, fire color sync, or all
  four. `--list-backups` on any of these scripts shows what's available.

This only covers configuration (GNOME settings + dotfiles) — installed
packages from `apt`/`go install` are left alone, since auto-uninstalling
tools is riskier than it's worth.

## What's in each toolkit

**General (`02-general-tools.sh`)** — zsh, tmux, fzf, ripgrep, bat, neovim,
htop/btop, flameshot, and the everyday utilities that have nothing to do
with security work but make the desktop pleasant to use.

**Bug bounty (`03-bugbounty-tools.sh`)** — the ProjectDiscovery suite
(subfinder, httpx, nuclei, naabu, katana), tomnomnom's tools (waybackurls,
anew, assetfinder), ffuf, dalfox, gobuster, plus apt-shipped staples
(nmap, sqlmap, Burp Suite, wpscan, amass, hydra).

**CTF (`04-ctf-tools.sh`)** — gdb + pwndbg, radare2, checksec, binwalk,
steghide/foremost for forensics, john/hashcat for crypto, and a dedicated
Python venv with pwntools, ropper, and angr so pwn dependencies stay
isolated from the system Python.

**GNOME (`06-gnome-setup.sh` + `gnome-tweaks.sh`)** — installs GNOME
Tweaks, Extension Manager, dconf-editor, and GSConnect (phone integration
— enable it manually via Extension Manager and pair it afterward), then
applies the settings described above. `dotfiles/gnome/extensions.txt` has
a curated list of extensions worth adding by hand (Dash to Dock, ArcMenu,
Clipboard Indicator, Vitals, and a few others), with notes on why they're
manual rather than scripted.

## Dotfiles

zsh config is split into `exports.zsh` (PATH/env), `aliases.zsh` (shortcuts
for git, tmux, recon, and CTF workflows), and `functions.zsh` (helpers like
`newtarget <domain>` and `newctf <category> <name>` to scaffold working
directories). `install.sh --dotfiles` symlinks all of it into `$HOME`,
backing up anything it would overwrite (see **Backups & undo** above).

## Notes

See [`docs/SETUP_GUIDE.md`](docs/SETUP_GUIDE.md) for the full install
walkthrough and re-run/reset instructions.

## License

MIT — see [LICENSE](LICENSE). Use, fork, and adapt freely.
