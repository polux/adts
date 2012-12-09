// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library parser_test;

import 'package:adts/adt_parser.dart';
import 'package:adts/generator.dart';

main() {
  final s = '''
    /* an example featuring the whole syntax */

    adt List<A> = Nil() | Cons(A head, List<A> tail)

    adt Foo = Bar() | Baz(int n)
  ''';
  final ast = adtParser.parse(s);
  print(generate(ast, new Configuration()));
}