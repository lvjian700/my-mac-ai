# Agent Guide

This file provides guidance to coding agents, including Codex and Claude Code, when working in this repository.

## Monorepo Structure

This is a macOS-focused monorepo. Each top-level folder is a standalone app or tool.

| Folder | Description |
|--------|-------------|
| `ical/` | CLI app to access Apple Calendar from the terminal (Swift 6, EventKit, swift-argument-parser) |

See each app's own `AGENTS.md` for build commands and architecture. `AGENTS.md` is the canonical agent file; `CLAUDE.md` should be a symlink to it for Claude Code.

## Coding

Run build and test every time you complete a task.
