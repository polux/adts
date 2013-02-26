// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library generator;

import 'package:adts/ast.dart';

class Configuration {
  final bool finalFields;
  final bool isGetters;
  final bool asGetters;
  final bool copyMethod;
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
    bool copyMethod: true,
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
     , this.copyMethod = copyMethod
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

_lines(Iterable ss) =>
    ss.join('\n');

_commas(Iterable ss) =>
    ss.join(', ');

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
                 List<DataTypeDefinition> defs,
                 List<Class> classes) {

  Map<String, Class> classMap = {};
  for (final c in classes) {
    classMap[c.name] = c;
  }

  bool overriden(String className, String methodName) {
    return classMap.containsKey(className)
        && classMap[className].methods.containsKey(methodName);
  }

  void write(String s) {
    buffer.write(s);
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
    final args = acc.join(sep);
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
    if (config.finalFields
        && config.equality
        && !overriden(cons.name, 'hashCode')) {
      writeLn('  final int hashCode;');
    }

    // constructor
    if (config.finalFields
        && config.equality
        && !overriden(cons.name, 'hashCode')) {
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
    final isCons = 'is${cons.name}';
    if (config.isGetters && !overriden(cons.name, isCons)) {
      writeLn('  bool get $isCons => true;');
    }

    // asCons
    final asCons = 'as${cons.name}';
    if (config.asGetters && !overriden(cons.name, asCons)) {
      writeLn('  ${cons.name}${typeArgs} get $asCons => this;');
    }

    // ==
    if (config.equality && !overriden(cons.name, '==')) {
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
    if (config.equality && !overriden(cons.name, 'hashCode')) {
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
    if (config.toStringMethod && !overriden(cons.name, 'toString')) {
      writeLn('  String toString() {');
      final args = cons.parameters.map((p) => '\$${p.name}');
      writeLn("    return '${cons.name}(${_commas(args)})';");
      writeLn('  }');
    }

    // accept
    if (config.visitor && !overriden(cons.name, 'accept')) {
      final xargs = _typeArgs(def.variables, 'Object');
      writeLn('  Object accept(${def.name}Visitor${xargs} visitor) {');
      writeLn('    return visitor.visit${cons.name}(this);');
      writeLn('  }');
    }

    // match
    if (config.matchMethod && !overriden(cons.name, 'match')) {
      generateMatchMethodPrefix(def);
      writeLn(' {');
      final args = _commas(cons.parameters.map((p) => p.name));
      final low = cons.name.toLowerCase();
      writeLn('    return $low($args);');
      writeLn('  }');
    }

    // copy method
    if (config.copyMethod && !cons.parameters.isEmpty
        && !overriden(cons.name, 'copy')) {
      writeLn('  ${cons.name}${typeArgs} copy({$typedParams}) {');
      writeLn('    return new ${cons.name}(');
      final acc = [];
      for (final p in cons.parameters) {
        acc.add('        ?${p.name} ? ${p.name} : this.${p.name}');
      }
      write(acc.join(',\n'));
      writeLn(');');
      writeLn('  }');
    }

    // overriden/extra methods
    final userClass = classMap[cons.name];
    if (userClass != null) {
      userClass.methods.forEach((_, m) {
        writeLn('  ${m.text}');
      });
    }

    writeLn('}');
  }

  void generateSuperClass(DataTypeDefinition def) {
    final typeArgs = _typeArgs(def.variables);

    writeLn('abstract class ${_typeRepr(def)} {');

    // isCons
    if (config.isGetters) {
      for (final c in def.constructors) {
        final isCons = 'is${c.name}';
        if (!overriden(def.name, isCons)) {
          writeLn('  bool get $isCons => false;');
        }
      }
    }

    // asCons
    if (config.asGetters) {
      for (final c in def.constructors) {
        final asCons = 'as${c.name}';
        if (!overriden(def.name, asCons)) {
          writeLn('  ${c.name}${typeArgs} get $asCons => null;');
        }
      }
    }

    // accept
    if (config.visitor
        && !def.constructors.isEmpty
        && !overriden(def.name, 'accept')) {
      final xargs = _typeArgs(def.variables, 'Object');
      writeLn('  Object accept(${def.name}Visitor${xargs} visitor);');
    }

    // match
    if (config.matchMethod
        && !def.constructors.isEmpty
        && !overriden(def.name, 'accept')) {
      generateMatchMethodPrefix(def);
      writeLn(';');
    }

    // overriden/extra methods
    final userClass = classMap[def.name];
    if (userClass != null) {
      userClass.methods.forEach((_, m) {
        writeLn('  ${m.text}');
      });
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
    final visitorName = '${def.name}Visitor';

    writeLn('abstract class $visitorName${xargs} {');

    // visit methods
    for (final c in def.constructors) {
      final low = c.name.toLowerCase();
      final visitCons = 'visit${c.name}';
      if (!overriden(visitorName, visitCons)) {
        writeLn('  $fresh $visitCons(${c.name}${args} ${low});');
      }
    }

    // overriden/extra methods
    final userClass = classMap[visitorName];
    if (userClass != null) {
      userClass.methods.forEach((_, m) {
        writeLn('  ${m.text}');
      });
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

String generate(Module module, Configuration configuration) {
  StringBuffer buffer = new StringBuffer();
  _generate(configuration, buffer, module.adts, module.classes);
  return buffer.toString();
}
