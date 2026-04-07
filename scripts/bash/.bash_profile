#!/usr/bin/env bash

# Login shells: load POSIX profile first (env for all shells)
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

# For interactive Bash login shells, also load the main Bash config
[[ -n $BASH && $- == *i* && -f "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
