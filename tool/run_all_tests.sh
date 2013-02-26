#!/bin/bash

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo "dart_analyzer --work=/tmp lib/*.dart"
results=`dart_analyzer --work=/tmp lib/*.dart 2>&1`

if [ -n "$results" ]; then
    echo "$results"
    exit 1
else
    echo "done"
fi

TMPFILE=`mktemp --suffix .dart`

echo "dart --enable-checked-mode example/demo.dart > $TMPFILE"
dart --enable-checked-mode $ROOT_DIR/example/demo.dart > $TMPFILE

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then

  exit 1
else
  echo "done"
fi

echo "echo 'main() { new Cons<int>(1, new Cons<int>(2, new Nil<int>())); }' >> $TMPFILE'"
echo 'main() { new Cons<int>(1, new Cons<int>(2, new Nil<int>())); }' >> $TMPFILE

echo "dart_analyzer --work=/tmp $TMPFILE"
results=`dart_analyzer --work=/tmp $TMPFILE 2>&1`

if [ -n "$results" ]; then
    echo "$results"
    exit 1
else
    echo "done"
fi

