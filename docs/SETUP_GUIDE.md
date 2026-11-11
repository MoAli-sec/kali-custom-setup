# Setup Guide

Detailed notes that don't fit in the top-level README — troubleshooting,
manual steps, and background on some of the choices in this repo.

## Fresh install order

1. Install Kali Linux (this repo assumes a fresh minimal or standard install).
2. Clone this repo:
   ```bash
   git clone https://github.com/MoAli-sec/kali-custom-setup.git
   cd kali-custom-setup
   chmod +x install.sh revert.sh gnome-tweaks.sh scripts/*.sh
   ```
3. Run `./install.sh` and pick "Everything", or run individual modules with
   flags (`--general`, `--bugbounty`, `--ctf`, `--zsh`, `--gnome`, `--dotfiles`).
4. Log out and back in (for the shell change and some GNOME settings to
   fully apply).
5. Open Powerlevel10k's config wizard on first zsh launch (`p10k configure`)
   if you want to customize the prompt beyond the defaults.

If anything looks wrong afterward — a setting you didn't want, a dotfile
overwritten — run `./install.sh --revert` (or `./revert.sh` directly). See
**Reverting changes** below for exactly what that restores.

## Re-running individual scripts

Every script under `scripts/` is idempotent — it checks whether something
is already installed/configured before touching it, so it's always safe to
re-run a single module (e.g. after `apt update` adds a new package, or after
wiping `~/tools`) without redoing the whole build.

## Reverting changes

Two things get backed up automatically, and both can be undone:

- **GNOME settings**: every run of `gnome-tweaks.sh` (directly, or via
  `install.sh --gnome`) dumps your full `/org/gnome/` dconf tree to
  `~/.kali-custom-setup-backups/gnome/<timestamp>/` first.
  `./gnome-tweaks.sh --revert` loads the most recent one back;
  `./gnome-tweaks.sh --revert <name>` loads a specific one (see
  `--list-backups` for names).
- **Dotfiles**: `07-dotfiles-setup.sh` moves any file it would overwrite
  into `~/.kali-custom-setup-backups/dotfiles/<timestamp>/` along with a
  manifest, before symlinking. `./scripts/07-dotfiles-setup.sh --revert`
  removes the symlinks and restores exactly what was there before —
  including correctly leaving removed anything that didn't exist
  previously, rather than inventing a blank file for it.

`./revert.sh` (also reachable as `./install.sh --revert`) is the one-stop
version: an interactive menu to revert GNOME, dotfiles, or both, plus a
`--list-backups` that shows everything available across both.

Reverting only ever touches configuration — it never uninstalls packages,
so your bug bounty/CTF tooling is untouched either way.

## Wiping and starting over

If a script partially fails and you want a clean slate for that module:

```bash
# example: fully reset the bug bounty toolkit
rm -rf ~/go/bin ~/tools/bugbounty
./install.sh --bugbounty
```

For GNOME settings or dotfiles specifically, prefer `--revert` (above)
over manually deleting things — it restores your actual prior state
instead of just wiping forward.

## Known gaps / things to expand later

- GNOME extensions aren't scripted (see `dotfiles/gnome/extensions.txt` for
  why) — install those manually after the first boot.
- Burp Suite Professional license/config isn't part of this repo (only the
  free Community Edition ships via apt) — activate Pro manually if you have
  a license.
- Wordlists (SecLists is installed via apt) live under
  `/usr/share/seclists` — not duplicated in this repo to keep it lightweight.
