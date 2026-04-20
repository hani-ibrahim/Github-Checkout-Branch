# Github Checkout Branch

`gco` and `gcb` are lightweight Git helpers for fast branch switching.

- `gco` finds a branch from cached `origin/*` refs and switches to it.
- `gcb` refreshes remote refs and cleans up merged or deleted branches/worktrees.
- In a worktree workspace, `gco` opens or creates a dedicated worktree for the selected branch.
- In a normal repository, `gco` switches the current repo to the selected branch.

## Commands

### `gco`

`gco <branch-name-or-partial-name>`

Checks out a branch by searching cached `origin/*` refs.

Search order:

1. exact match first
2. case-insensitive partial match second

If exactly one branch matches, `gco` switches to it immediately.
If multiple branches match, `gco` shows an interactive numbered list and asks you to choose one.

#### Parameters

| Parameter | Required | Description |
| :-------- | :------- | :---------- |
| `<branch-name-or-partial-name>` | yes | The text to search for in cached `origin/*` refs |

Supported and unsupported input forms:

| Input form | Example | Supported | Notes |
| :--------- | :------ | :-------- | :---- |
| Full branch name | `gco main` | yes | Exact match is checked first |
| Beginning of branch name | `gco dev` | yes | Uses case-insensitive partial matching when exact match is not found |
| Unique substring inside branch name | `gco 104` | yes | Works if it resolves to one branch |
| Mixed-case search text | `gco TICKET` | yes | Partial matching is case-insensitive |
| Second positional index (unsupported) | `gco ticket 2` | no | Not implemented in the current script |
| Flag-based index selection (unsupported) | `gco --index 2` | no | `gco` does not accept flags |
| Non-interactive disambiguation (unsupported) | `printf "1\n" \| gco ticket` | no | Multiple matches require an interactive TTY |

#### Examples

Given these remote branches:

- `main`
- `develop`
- `release-2.2`
- `ticket-104-fix-readme`
- `ticket-77-update-translations`

Then:

| Command | What matches | Result |
| :------ | :----------- | :----- |
| `gco main` | exact match: `main` | Switch to `main` |
| `gco develop` | exact match: `develop` | Switch to `develop` |
| `gco dev` | partial match: `develop` | Switch to `develop` |
| `gco 2.2` | partial match: `release-2.2` | Switch to `release-2.2` |
| `gco 104` | partial match: `ticket-104-fix-readme` | Switch to `ticket-104-fix-readme` |
| `gco TICKET` | partial matches, case-insensitive | Show a selection list |
| `gco ticket` | `ticket-104-fix-readme`, `ticket-77-update-translations` | Show a selection list |
| `gco missing` | no matches | Print an error |

#### Interactive selection example

If more than one branch matches:

```text
$ gco ticket
More than one branch found:
1. ticket-104-fix-readme
2. ticket-77-update-translations
Please select a branch: 2
```

`gco` then checks out `ticket-77-update-translations`.

#### Behavior in each mode

In a normal repository:

- if the local branch already exists, `gco` switches to it
- otherwise it creates or resets the local branch from `refs/remotes/origin/<branch>`
- then it switches the current repository to that branch

In a worktree workspace:

- if the branch is already checked out in another worktree, `gco` changes into that worktree
- otherwise it creates the local branch from `refs/remotes/origin/<branch>`
- then it creates a worktree under `<workspace-root>/<branch>`
- finally it changes into that worktree directory

#### Errors and edge cases

`gco` fails with an error when:

- no query is provided
- you are not inside a supported git repository or worktree workspace
- no cached `origin/*` refs exist yet
- the branch does not exist in the cached refs
- multiple branches match but there is no interactive TTY available

When a branch was created recently on the remote, run `gcb` first to refresh the cache.

### `gcb`

`gcb [--force]`

Refreshes the branch cache used by `gco`.

#### Parameters

| Parameter | Required | Description |
| :-------- | :------- | :---------- |
| `--force` | no | Force-remove stale worktrees even if they have uncommitted changes |
| `-f` | no | Short form of `--force` |

#### Examples

| Command | Result |
| :------ | :----- |
| `gcb` | Refresh remote refs and clean up safe-to-remove branches/worktrees |
| `gcb --force` | Same as `gcb`, but also force-remove dirty stale worktrees in worktree mode |
| `gcb -f` | Short form of `gcb --force` |

In a normal repository it:

- runs `git fetch origin --prune`
- updates `origin/HEAD`
- deletes local branches already merged into the default branch
- runs `git pull --rebase`

Notes for normal repository mode:

- `--force` has no effect here
- merged local branches are deleted automatically, excluding the current branch and the default branch

In a worktree workspace it:

- refreshes `refs/remotes/origin/*`
- prunes stale remote-tracking refs
- removes worktrees whose branches were deleted on origin
- removes worktrees already merged into the remote default branch
- skips dirty worktrees unless `--force` is provided
- runs `git pull --rebase` when inside a checked-out worktree

Notes for worktree mode:

- a worktree may be removed because its branch was deleted on `origin`
- a worktree may also be removed because its branch is already merged into the remote default branch
- without `--force`, dirty worktrees are kept and a warning is printed
- with `--force`, dirty stale worktrees are removed with `git worktree remove --force`

## Usage Notes

- Run `gcb` before `gco` if a branch was created recently.
- `gco` only searches cached remote refs, not the network directly.
- In worktree mode, branches are created under the workspace root using the branch name as the path.

## Repository Modes

### Normal Repository Mode

This is a standard Git repository with a regular `.git` directory.

Typical flow:

```text
gcb
gco feature
```

Effect:

- `gcb` refreshes remote refs and removes merged local branches
- `gco` switches the current repository to the selected branch

### Worktree Workspace Mode

This is a workspace whose root contains a shared bare clone in `.bare`.

Expected structure:

```text
/workspace
├── .bare
├── main
├── develop
└── ticket-104-fix-readme
```

What each path is:

- `/workspace/.bare` is the shared bare clone
- `/workspace/main` is a worktree for the `main` branch
- `/workspace/develop` is a worktree for the `develop` branch
- `/workspace/ticket-104-fix-readme` is a worktree for that feature branch

The main folder is the workspace root itself, and `.bare` lives inside it.
`gco` detects this mode by checking for a `.bare` directory in the current workspace root.

Example setup:

```sh
mkdir -p ~/work/my-repo
git clone --bare git@github.com:your-org/your-repo.git ~/work/my-repo/.bare
git --git-dir=~/work/my-repo/.bare remote set-head origin -a
git --git-dir=~/work/my-repo/.bare worktree add ~/work/my-repo/main main
```

After that, the workspace looks like:

```text
~/work/my-repo
├── .bare
└── main
```

From there, running `gco develop` can create or open `~/work/my-repo/develop`.

Typical flow:

```text
cd /workspace
gcb
gco ticket
```

Effect:

- `gcb` refreshes the shared remote cache and removes stale worktrees
- `gco` opens an existing worktree for the selected branch, or creates a new one if needed

## Installation

Clone the repository into the current directory and enter it:

```sh
git clone git@github.com:hani-ibrahim/Github-Checkout-Branch.git
cd Github-Checkout-Branch
```

Add both scripts to your shell startup file so they are available in every new terminal session.

Example:

```sh
echo "source \"$PWD/gco.zsh\"" >> ~/.zshrc
echo "source \"$PWD/gcb.zsh\"" >> ~/.zshrc
```

Reload your shell config:

```sh
source ~/.zshrc
```

If you use a different startup file, add the same `source ...` lines there instead.

## Worktree Workspace Setup Example

If you want to use the `.bare` workspace mode, create the repository like this:

```sh
mkdir -p ~/work/my-repo
git clone --bare git@github.com:your-org/your-repo.git ~/work/my-repo/.bare
git --git-dir=~/work/my-repo/.bare fetch origin --prune
git --git-dir=~/work/my-repo/.bare remote set-head origin -a
git --git-dir=~/work/my-repo/.bare worktree add ~/work/my-repo/main main
```

Then work from the workspace root:

```sh
cd ~/work/my-repo
gcb
gco develop
```

This gives you a layout like:

```text
~/work/my-repo
├── .bare
├── main
└── develop
```

## Quick Start

1. Open a repository or worktree workspace.
2. Run `gcb` to refresh cached remote branches.
3. Run `gco <query>` to switch to the branch you want.
4. If multiple branches match, choose one from the interactive list.

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
