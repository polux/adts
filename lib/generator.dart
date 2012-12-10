// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library generator;

import 'package:adts/ast.dart';

class Configuration {
  final bool finalFields;
  final bool isGetters;
  final bool asGetters;
  final bool withMethod;
  final bool equality;
  final bool toStringMethod;
  final bool fromString;
  final bool parser;
  final bool enumerator;
  final bool visitor;
  final bool matchMethod;
  final bool extractor;
  final bool toJson;
  final bool fromJson;

  Configuration({
    bool finalFields: true,
    bool isGetters: true,
    bool asGetters: true,
    bool withMethod: true,
    bool equality: true,
    bool toStringMethod: true,
    bool fromString: true,
    bool parser: false,
    bool enumerator: false,
    bool visitor: true,
    bool matchMethod: true,
    bool extractor: true,
    bool toJson: true,
    bool fromJson: true
  }) : this.finalFields = finalFields
     , this.isGetters = isGetters
     , this.asGetters = asGetters
     , this.withMethod = withMethod
     , this.equality = equality
     , this.toStringMethod = toStringMethod
     , this.fromString = fromString
     , this.parser = parser
     , this.enumerator = enumerator
     , this.visitor = visitor
     , this.matchMethod = matchMethod
     , this.extractor = extractor
     , this.toJson = toJson
     , this.fromJson = fromJson;
}

_lines(List ss) =>
    Strings.join(ss, '\n');

_commas(List ss) =>
    Strings.join(ss, ', ');

String _typeArgs(List args, [String extraArg]) {
  if (extraArg != null) {
    args = new List.from(args)..add(extraArg);
  }
  return args.isEmpty ? '' : '<${_commas(args)}>';
}

String _typeRepr(DataTypeDefinition def) =>
    "${def.name}${_typeArgs(def.variables)}";

String _freshTypeVar(String v, List<String> typeVars) {
  while(typeVars.contains(v)) {
    v = '${v}_';
  }
  return v;
}

String _generate(Configuration config, StringBuffer buffer,
                 List<DataTypeDefinition> defs) {

  void write(String s) {
    buffer.add(s);
  }

  void writeLn(String s) {
    write('$s\n');
  }

  void generateMatchMethodPrefix(DataTypeDefinition def) {
    List<String> acc = [];
    for (final c in def.constructors) {
      final low = c.name.toLowerCase();
      final typedParams = _commas(
          c.parameters.map((p) => '${p.type} ${p.name}'));
      acc.add('Object $low($typedParams)');
    }
    final sep = ',\n                ';
    final args = Strings.join(acc, sep);
    write('  Object match({$args})');
  }

  void generateConstructorClass(DataTypeDefinition def, Constructor cons) {
    final typeArgs = _typeArgs(def.variables);
    final typedParams = _commas(
        cons.parameters.map((p) => '${p.type} ${p.name}'));

    writeLn('class ${cons.name}${typeArgs} extends ${_typeRepr(def)} {');

    // fields
    for (final p in cons.parameters) {
      final modifier = config.finalFields ? 'final ' : '';
      writeLn('  $modifier$p;');
    }
    if (config.finalFields && config.equality) {
      writeLn('  final int hashCode;');
    }

    // constructor
    if (config.equality && config.finalFields) {
      write('  ${cons.name}($typedParams)');
      bool first = true;
      for (final p in cons.parameters) {
        final sep = first ? ':' : ',';
        write('\n      $sep this.${p.name} = ${p.name}');
        first = false;
      }
      final sep = first ? ' :' : '\n      ,';
      final params = cons.parameters.map((p) => p.name);
      writeLn('$sep this.hashCode = '
              '${cons.name}._hashCode(${_commas(params)});');
    } else {
      final thisParams = cons.parameters.map((p) => 'this.${p.name}');
      writeLn('  ${cons.name}(${_commas(thisParams)});');
    }

    // isCons
    if (config.isGetters) {
      writeLn('  bool get is${cons.name} => true;');
    }

    // asCons
    if (config.asGetters) {
      writeLn('  ${cons.name}${typeArgs} get as${cons.name} => this;');
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
      if (!config.finalFields) {
        writeLn('  int get hashCode {');
      } else {
        final params = _commas(cons.parameters.map((p) => p.name));
        writeLn('  static int _hashCode($params) {');
      }
      writeLn('    int result = "${cons.name}".hashCode;');
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

    // accept
    if (config.visitor) {
      final xargs = _typeArgs(def.variables, 'Object');
      writeLn('  Object accept(${def.name}Visitor${xargs} visitor) {');
      writeLn('    return visitor.visit${cons.name}(this);');
      writeLn('  }');
    }

    // match
    if (config.matchMethod) {
      generateMatchMethodPrefix(def);
      writeLn(' {');
      final args = _commas(cons.parameters.map((p) => p.name));
      final low = cons.name.toLowerCase();
      writeLn('    return $low($args);');
      writeLn('  }');
    }

    // with method
    if (config.withMethod && !cons.parameters.isEmpty) {
      writeLn('  ${cons.name}${typeArgs} with({$typedParams}) {');
      writeLn('    return new ${cons.name}(');
      final acc = [];
      for (final p in cons.parameters) {
        acc.add('        ?${p.name} ? ${p.name} : this.${p.name}');
      }
      write(Strings.join(acc, ',\n'));
      writeLn(');');
      writeLn('  }');
    }

    writeLn('}');
  }

  void generateSuperClass(DataTypeDefinition def) {
    final typeArgs = _typeArgs(def.variables);

    writeLn('abstract class ${_typeRepr(def)} {');

    // isCons
    if (config.isGetters) {
      for (final c in def.constructors) {
        writeLn('  bool get is${c.name} => false;');
      }
    }

    // asCons
    if (config.asGetters) {
      for (final c in def.constructors) {
        writeLn('  ${c.name}${typeArgs} get as${c.name} => null;');
      }
    }

    // accept
    if (config.visitor && !def.constructors.isEmpty) {
      final xargs = _typeArgs(def.variables, 'Object');
      writeLn('  Object accept(${def.name}Visitor${xargs} visitor);');
    }

    // match
    if (config.matchMethod && !def.constructors.isEmpty) {
      generateMatchMethodPrefix(def);
      writeLn(';');
    }

    writeLn('}');
  }

  void generateVisitorClass(DataTypeDefinition def) {
    if (def.constructors.isEmpty) {
      return;
    }
    final fresh = _freshTypeVar('R', def.variables);
    final args = _typeArgs(def.variables);
    final xargs = _typeArgs(def.variables, fresh);
    writeLn('abstract class ${def.name}Visitor${xargs} {');
    for (final c in def.constructors) {
      final low = c.name.toLowerCase();
      writeLn('  $fresh visit${c.name}(${c.name}${args} ${low});');
    }
    writeLn('}');
  }

  void generateDefinition(DataTypeDefinition def) {
    generateSuperClass(def);
    writeLn('');
    if (config.visitor) {
      generateVisitorClass(def);
      writeLn('');
    }
    for (final cons in def.constructors) {
      generateConstructorClass(def, cons);
      writeLn('');
    }
  }

  void generateImports() {
    bool written = false;
    if (config.parser) {
      writeLn("import 'package:parsers/parsers.dart' as parsers;");
      written = true;
    }
    if (config.enumerator) {
      writeLn("import 'package:enumerators/enumerators.dart' as enumerators;");
      writeLn("import 'package:enumerators/combinators.dart' as combinators;");
      written = true;
    }
    if (written) {
      writeLn('');
    }
  }

  generateImports();
  for (final def in defs) {
    generateDefinition(def);
    writeLn('');
  }
}

String generate(List<DataTypeDefinition> defs, Configuration configuration) {
  StringBuffer buffer = new StringBuffer();
  _generate(configuration, buffer, defs);
  return buffer.toString();
}
