# github.com/edwinhern/dotfiles

Edwin's dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Install on a Mac

One command — installs `chezmoi` to `~/.local/bin` if missing, clones this repo, and applies it to `$HOME`:

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" -- init --apply edwinhern
```

## Working on this repo

These tasks operate against the local clone (via `chezmoi --source $PWD`), so you can test edits without pushing:

```sh
mise update            # apply local source state to $HOME
mise diff              # preview what apply would change
mise format            # format shell, md, yaml, toml
mise lint              # lint shell, md, yaml, toml
mise test              # run bats tests
mise coverage          # run bats under kcov, write report to coverage/ (needs kcov)
mise check             # lint + test
```
