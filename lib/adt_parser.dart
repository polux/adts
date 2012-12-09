// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library adt_parser;

import 'package:adts/ast.dart';
import 'package:parsers/parsers.dart';

class _AdtParsers extends LanguageParsers {
  _AdtParsers() : super(reservedNames: ['adt']);

  get adt => whiteSpace > (def.many < eof);

  get def =>
      reserved['adt']
      + identifier
      + angles(identifier.sepBy(comma)).orElse([])
      + symbol('=')
      + constructor.sepBy(symbol('|'))
      ^ (_, c, vs, __, cs) => new DataTypeDefinition(c, vs, cs);

  get constructor =>
      identifier + parens(parameter.sepBy(comma))
      ^ (c, ts) => new Constructor(c, ts);

  get parameter =>
      typeAppl()
      + identifier
      ^ (t, p) => new Parameter(t, p);

  typeAppl() =>
      identifier
      + angles(rec(typeAppl).sepBy(comma)).orElse([])
      ^ (c, args) => new TypeAppl(c, args);
}

final Parser<List<DataTypeDefinition>> adtParser = new _AdtParsers().adt;