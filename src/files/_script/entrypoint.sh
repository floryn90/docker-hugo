#!/bin/bash
if [ -n "$CI_PROJECT_DIR" ]; then
  git config --global --add safe.directory "$CI_PROJECT_DIR"
fi
exec "$@"