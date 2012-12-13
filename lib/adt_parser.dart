// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library adt_parser;

import 'package:adts/ast.dart';
import 'package:parsers/parsers.dart';

class _AdtParsers extends LanguageParsers {
  _AdtParsers() : super(reservedNames: ['data', 'class', 'get'],
                        nestedComments: true);

  get module =>
      whiteSpace
      + def.many
      + classDecl.many
      + eof
      ^ (_, adts, classes, __) => new Module(adts, classes);

  get adt => whiteSpace > (def.many < eof);

  get def =>
      reserved['data']
      + identifier
      + angles(identifier.sepBy(comma)).orElse([])
      + symbol('=')
      + constructor.sepBy(symbol('|'))
      ^ (_, c, vs, __, cs) => new DataTypeDefinition(c, vs, cs);

  get constructor =>
      identifier + parens(parameter.sepBy(comma))
      ^ (c, ts) => new Constructor(c, ts);

  get parameter =>
      (typeAppl() % 'type')
      + (identifier % 'parameter')
      ^ (t, p) => new Parameter(t, p);

  typeAppl() =>
      identifier
      + angles(rec(typeAppl).sepBy(comma)).orElse([])
      ^ (c, args) => new TypeAppl(c, args);

  get classDecl =>
      reserved['class']
      + identifier
      + braces(classBody)
      ^ (_, n, ms) => new Class(n, ms);

  get classBody => method.many;

  get method => lexeme(_method);
  get _method => getMethod | regularMethod;

  get getMethod =>
      typeAppl().record
      + reserved['get'].record
      + identifier.record
      + methodBody.record
      ^ (t, g, n, b) => new Method(n.trim(), '$t$g$n$b');

  get regularMethod =>
      typeAppl().record
      + identifier.record
      + parens(parameter.sepBy(comma)).record
      + methodBody.record
      ^ (t, n, as, b) => new Method(n.trim(), '$t$n$as$b');

  get methodBody =>
      char(';')
    | string('=>') > anyChar.skipManyUntil(char(';'))
    | multiLineBody();

  multiLineBody() => char('{') > inMethodBody();

  inMethodBody() => noneOf('{}').skipMany > scopeOrEnd();

  scopeOrEnd() => char('}') | rec(multiLineBody) > rec(inMethodBody);
}

final Parser<Module> moduleParser = new _AdtParsers().module;