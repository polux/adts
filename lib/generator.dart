// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library generator;

import 'package:adts/ast.dart';

class Configuration {
  final bool isGetters;
  final bool asGetters;
  final bool equality;
  final bool toStringMethod;
  final bool fromString;
  final bool parser;
  final bool enumerator;
  final bool visitor;
  final bool extractor;
  final bool toJson;
  final bool fromJson;

  Configuration({
    bool isGetters: true,
    bool asGetters: true,
    bool equality: true,
    bool toStringMethod: true,
    bool fromString: true,
    bool parser: true,
    bool enumerator: true,
    bool visitor: true,
    bool extractor: true,
    bool toJson: true,
    bool fromJson: true
  }) : this.isGetters = isGetters
     , this.asGetters = asGetters
     , this.equality = equality
     , this.toStringMethod = toStringMethod
     , this.fromString = fromString
     , this.parser = parser
     , this.enumerator = enumerator
     , this.visitor = visitor
     , this.extractor = extractor
     , this.toJson = toJson
     , this.fromJson = fromJson;
}

_lines(List ss) =>
    Strings.join(ss, '\n');

_commas(List ss) =>
    Strings.join(ss, ', ');

String _typeArgs(List args) =>
    args.isEmpty ? '' : '<${_commas(args)}>';

String _typeRepr(DataTypeDefinition def) =>
    "${def.name}${_typeArgs(def.variables)}";

class _Generator {
  final Configuration config;
  final StringBuffer buffer;

  _Generator(this.config, this.buffer);

  void write(String s) {
    buffer.add(s);
  }

  void writeLn(String s) {
    write('$s\n');
  }

  void generate(List<DataTypeDefinition> defs) {
    for (final def in defs) {
      generateDefinition(def);
      writeLn('');
    }
  }

  void generateDefinition(DataTypeDefinition def) {
    generateSuperClass(def);
    writeLn('');
    for (final cons in def.constructors) {
      generateConstructorClass(def, cons);
      writeLn('');
    }
  }

  void generateSuperClass(DataTypeDefinition def) {
    final typeArgs = _typeArgs(def.variables);

    writeLn('abstract class ${_typeRepr(def)} {');

    // isCons
    if (config.isGetters) {
      for (final c in def.constructors) {
        writeLn('  bool get is${c.name};');
      }
    }

    // asCons
    if (config.asGetters) {
      for (final c in def.constructors) {
        writeLn('  ${c.name}${typeArgs} get as${c.name};');
      }
    }
    writeLn('}');
  }

  void generateConstructorClass(DataTypeDefinition def,
                                Constructor cons) {
    final typeArgs = _typeArgs(def.variables);
    writeLn('class ${cons.name}${typeArgs} extends ${_typeRepr(def)} {');

    // fields
    for (final p in cons.parameters) {
      writeLn('  $p;');
    }

    // constructor
    final List thisArgs = cons.parameters.map((p) => 'this.${p.name}');
    writeLn('  ${cons.name}(${_commas(thisArgs)});');

    // isCons
    if (config.isGetters) {
      for (final c in def.constructors) {
        writeLn('  bool get is${c.name} => ${c == cons};');
      }
    }

    // asCons
    if (config.asGetters) {
      for (final c in def.constructors) {
        final rhs = c == cons ? 'this' : 'null';
        writeLn('  ${c.name}${typeArgs} get as${c.name} => $rhs;');
      }
    }

    // ==
    if (config.equality) {
      writeLn('  bool operator ==(other) {');
      writeLn('    return identical(this, other)');
      write('        || (other is ${cons.name}${typeArgs}');
      for (final p in cons.parameters) {
        write('\n            && ${p.name} == other.${p.name}');
      }
      writeLn(');');
      writeLn('  }');
    }

    // hashCode
    if (config.equality) {
      writeLn('  int get hashCode {');
      writeLn('    int result = 1;');
      for (final p in cons.parameters) {
        writeLn('    result = 31 * result + ${p.name}.hashCode;');
      }
      writeLn('    return result;');
      writeLn('  }');
    }

    // toString
    if (config.toStringMethod) {
      writeLn('  String toString() {');
      final List args = cons.parameters.map((p) => '\$${p.name}');
      writeLn("    return '${cons.name}(${_commas(args)})';");
      writeLn('  }');
    }

    writeLn('}');
  }
}

String generate(List<DataTypeDefinition> defs, Configuration configuration) {
  StringBuffer buffer = new StringBuffer();
  new _Generator(configuration, buffer).generate(defs);
  return buffer.toString();
}
