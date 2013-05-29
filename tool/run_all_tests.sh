#!/bin/bash

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

dartanalyzer $ROOT_DIR/lib/*.dart

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then

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

dartanalyzer $TMPFILE

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then

  exit 1
else
  echo "done"
fi


