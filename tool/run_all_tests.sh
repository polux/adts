#!/bin/bash

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo "dart --enable-checked-mode example/demo.dart"
dart --enable-checked-mode $ROOT_DIR/example/demo.dart > /dev/null

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  exit 1
else
  echo "done"
fi

echo "dart_analyzer lib/*.dart"
results=`dart_analyzer lib/*.dart 2>&1`

if [ -n "$results" ]; then
    echo "$results"
    exit 1
else
    echo "done"
fi