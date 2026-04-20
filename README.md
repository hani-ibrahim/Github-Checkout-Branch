# Github Checkout Branch

`gco` and `gcb` are lightweight Git helpers for fast branch switching.

- `gco` finds a branch from cached `origin/*` refs and switches to it.
- `gcb` refreshes remote refs and cleans up merged or deleted branches/worktrees.
- In a worktree workspace, `gco` opens or creates a dedicated worktree for the selected branch.
- In a normal repository, `gco` switches the current repo to the selected branch.

## Commands

### `gco`

`gco <query>`

Searches cached `origin/*` branches using:

1. exact match first
2. case-insensitive partial match second

If exactly one branch matches, `gco` switches to it immediately.
If multiple branches match, `gco` shows an interactive numbered list and asks you to choose one.

Example branches:

- `main`
- `develop`
- `release-2.2`
- `ticket-104-fix-readme`
- `ticket-77-update-translations`

Example usage:

| Command | Result |
| :------ | :----- |
| `gco main` | Switch to `main` |
| `gco dev` | Switch to `develop` |
| `gco 104` | Switch to `ticket-104-fix-readme` |
| `gco ticket` | Show matching branches and prompt for a selection |

### `gcb`

`gcb [--force]`

Refreshes the branch cache used by `gco`.

In a normal repository it:

- runs `git fetch origin --prune`
- updates `origin/HEAD`
- deletes local branches already merged into the default branch
- runs `git pull --rebase`

In a worktree workspace it:

- refreshes `refs/remotes/origin/*`
- prunes stale remote-tracking refs
- removes worktrees whose branches were deleted on origin
- removes worktrees already merged into the remote default branch
- skips dirty worktrees unless `--force` is provided
- runs `git pull --rebase` when inside a checked-out worktree

## Usage Notes

- Run `gcb` before `gco` if a branch was created recently.
- `gco` only searches cached remote refs, not the network directly.
- In worktree mode, branches are created under the workspace root using the branch name as the path.

## Installation

Clone the repository and source the scripts from your shell startup file:

```sh
git clone git@github.com:hani-ibrahim/Github-Checkout-Branch.git ~/Desktop/Github-Checkout-Branch
```

```sh
source ~/Desktop/Github-Checkout-Branch/gco.zsh
source ~/Desktop/Github-Checkout-Branch/gcb.zsh
```

Then reload your shell config.

## License

MIT License

> Copyright (c) 2017 Hani Ibrahim
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.
