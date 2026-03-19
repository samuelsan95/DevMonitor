# DevMonitor

A lightweight macOS menu bar app that monitors your local development servers in real time.

## What it does

DevMonitor sits quietly in your menu bar and shows you all TCP ports currently listening on your machine — so you always know which dev servers, databases, and services are running without opening a terminal.

![DevMonitor screenshot](screenshot.png)

## Features

- **Live process list** — detects all active TCP listeners via `lsof`
- **Smart icons & colors** — recognizes Node.js, Python, Ruby, Java, Nginx, PostgreSQL, MySQL, Redis, Docker and more
- **Open in browser** — click the Safari icon to open `localhost:<port>` instantly
- **Kill processes** — stop any running service with one click
- **Search** — filter by process name or port number
- **Auto-refresh** — configurable interval (5s / 10s / 30s / 60s)
- **Launch at startup** — optionally start DevMonitor when your Mac boots

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/samuelsan95/DevMonitor.git
   ```
2. Open `DevMonitor.xcodeproj` in Xcode
3. Select your development team in **Signing & Capabilities**
4. Press `Cmd + R` to build and run

## Usage

Once running, click the DevMonitor icon in the menu bar to see all active services. Use the **play/pause** button to toggle auto-refresh, the **search bar** to filter, and the gear icon to configure settings.

## License

MIT
