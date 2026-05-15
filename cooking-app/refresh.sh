#!/bin/zsh
cd "$(dirname "$0")"
swiftc main.swift -o CookingApp && cp CookingApp CookingApp.app/Contents/MacOS/CookingApp || exit 1
pkill -x CookingApp 2>/dev/null
sleep 0.3
open CookingApp.app
