#!/bin/bash

# Beschreibung:
# liste alle Pakete ohne Repo auf.

REPOS=$(zypper lr | tail +3 | cut -d"|" -f1 | sed "s/^/-r /g" | tr -d '\012')
INST_ALL=$(mktemp)
INST_REPO=$(mktemp)
rpm -qa | sort > "$INST_ALL"
zypper pa -i $REPOS | grep "^i"  | cut -d'|' -f 3-4 | tr -d ' ' | tr '|' '-' | sort > "$INST_REPO"

join -v 1 "$INST_ALL" "$INST_REPO"

rm "$INST_ALL" "$INST_REPO"
