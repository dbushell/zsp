# ⚡ ZSP

ZSP is my personal ZSH prompt written in [Zig](https://ziglang.org).

<img alt="screenshot of ZSP prompt in a terminal" src=".github/screenshot.avif" width="640">

From the blog:

* ["I built a ZSH Prompt with Zig"](https://dbushell.com/2025/03/05/zig-zsh-prompt/)
* ["Zig App Release and Updates via Github"](https://dbushell.com/2025/03/18/zig-app-release-and-updates-via-github/)

This is a hobby project for me to learn Zig software development.

## Usage

Ensure `zsp` binary is in `$PATH` and add to `.zshrc`:

```zsh
source <(zsp --zsh)
```

Optionally, a space-separated list of environment variables can be supplied
via the environment variable `ZSP_PROMPT_ENV_VARS`. Prefix an environment
variable name with and equal sign (`=`) to print the variable name and
value.  Otherwise, just the value will be printed.

```zsh
export ZSP_PROMPT_ENV_VARS="AWS_PROFILE =HOSTTYPE"
```

See [`src/shell/zsh.sh`](/src/shell/zsh.sh) for the source.

## 🚧 Under Construction!

I'm working on new features as I use the prompt day-to-day.

There is no config unless you edit the source code and recompile!

## Notes

Inspired by [Starship](https://github.com/starship/starship) and [Pure](https://github.com/sindresorhus/pure).

* * *

[MIT License](/LICENSE) | Copyright © 2025 [David Bushell](https://dbushell.com)
