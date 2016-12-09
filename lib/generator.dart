// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library generator;

import 'package:adts/ast.dart';
import 'package:adts/configuration.dart';
import 'package:persistent/persistent.dart';

_lines(Iterable ss) =>
    ss.join('\n');

_commas(Iterable ss, [int indent]) {
  if (indent == null) {
    return ss.join(', ');
  } else {
    StringBuffer spaces = new StringBuffer();
    for (int i = 0; i < indent; i++) spaces.write(' ');
    return ss.join(',\n$spaces');
  }
}

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

bool _isAtom(TypeAppl type) {
  final atoms = const ["int", "double", "num", "String"];
  return atoms.contains(type.name) && type.arguments.isEmpty;
}

bool _isList0(TypeAppl type) {
  return type.name == "List" && type.arguments.isEmpty;
}

bool _isList1(TypeAppl type) {
  return type.name == "List" && type.arguments.length == 1;
}


class Generator {

  final Configuration config;
  final StringBuffer buffer;
  final Option<String> libraryName;
  final List<String> imports;
  final List<DataTypeDefinition> defs;
  final List<Class> classes;
  final Map<String, Class> classMap = {};

  Generator(this.config, this.buffer, this.libraryName, this.imports, this.defs,
      this.classes) {
    for (final c in classes) {
      classMap[c.name] = c;
    }
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

  DataTypeDefinition dataTypeMatching(TypeAppl type) {
    final datatype = defs.firstWhere((d) => d.name == type.name,
        orElse: () => null);
    if (datatype != null
        && datatype.variables.length == type.arguments.length) {
      return datatype;
    }
  }

  bool isUnknownType(TypeAppl type) {
    return !_isAtom(type)
        && !_isList1(type)
        && dataTypeMatching(type) == null;
  }

  void generateMatchMethodPrefix(DataTypeDefinition def) {
    List<String> acc = [];
    for (final c in def.constructors) {
      final low = c.name.toLowerCase();
      final typedParams = _commas(
          c.parameters.map((p) => '${p.type} ${p.name}'));
      acc.add('Object $low($typedParams)');
    }
    acc.add('Object otherwise(): _nonExhaustive');
    final sep = ',\n                ';
    final args = acc.join(sep);
    write('  Object match({$args})');
  }

  String jsonRecursiveCall(String name, TypeAppl type) {
    if (_isAtom(type)) {
      return name;
    } else if (_isList1(type)) {
      final typeArg = type.arguments[0];
      if (_isAtom(typeArg)) {
        return name;
      } else {
        return '$name.map((x) => ${jsonRecursiveCall('x', typeArg)}).toList()';
      }
    } else if (_isList0(type)) {
      return '$name.map(_dynamicToJson).toList()';
    } else if (isUnknownType(type)) {
      return '_dynamicToJson($name)';
    } else {
      return '$name.toJson()';
    }
  }

  String fromJsonFunctionName(TypeAppl type) {
    stringify(bool first) => (TypeAppl type) {
      final name = first
          ? '${type.name[0].toLowerCase()}${type.name.substring(1)}'
          : type.name;
      if (type.arguments.isEmpty) {
        return name;
      } else {
        final args = type.arguments.map(stringify(false)).join();
        return '$name${args}';
      }
    };
    return '${stringify(true)(type)}FromJson';
  }

  String fromJsonRecursiveCall(String name, TypeAppl type) {
    final datatype = dataTypeMatching(type);
    if (datatype != null) {
      final subst = substitution(datatype, type.arguments);
      final extraArgs = unknownTypesOfDatatype(datatype)
          .map((ty) => fromJsonFunctionName(ty.subst(subst)));
      final args = [name]..addAll(extraArgs);
      return '${datatype.name}.fromJson(${_commas(args)})';
    } else if (_isAtom(type)) {
      return name;
    } else if (_isList1(type)) {
      final typeArg = type.arguments[0];
      if (_isAtom(typeArg)) {
        return name;
      } else {
        return '$name.map((x) => '
               '${fromJsonRecursiveCall('x', typeArg)}).toList()';
      }
    } else {
      return '${fromJsonFunctionName(type)}($name)';
    }
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
      writeLn('    return ($low != null) ? $low($args) : otherwise();');
      writeLn('  }');
    }

    // copy method
    if (config.copyMethod && !cons.parameters.isEmpty
        && !overriden(cons.name, 'copy')) {
      writeLn('  ${cons.name}${typeArgs} copy({$typedParams}) {');
      writeLn('    return new ${cons.name}(');
      final acc = [];
      for (final p in cons.parameters) {
        acc.add('        (${p.name} != null) ? ${p.name} : this.${p.name}');
      }
      write(acc.join(',\n'));
      writeLn(');');
      writeLn('  }');
    }

    // toJson
    if (config.toJson && !overriden(cons.name, 'toJson')) {
      writeLn('  Map toJson() {');
      final entries = cons.parameters.map((p) =>
          "'${p.name}': ${jsonRecursiveCall(p.name, p.type)}");
      final keyvals = [["'tag': '${cons.name}'"], entries].expand((x) => x);
      writeLn("    return { ${_commas(keyvals, 13)} };");
      writeLn('  }');
    }

    // fromJson
    if (config.fromJson && !overriden(cons.name, 'fromJson')) {
      signature(TypeAppl type) {
        final prefix = def.variables.contains(type.name) ? '' : '${type.name} ';
        return '$prefix${fromJsonFunctionName(type)}(Map json)';
      }
      final extraArgs = unknownTypesOfConstructor(cons).map(signature);
      final args = ['Map json']..addAll(extraArgs);
      final recArgs = cons.parameters.map((p) =>
          fromJsonRecursiveCall("json['${p.name}']", p.type));
      final prefix1 = '  static ${cons.name} fromJson(';
      final prefix2 = '    return new ${cons.name}(';
      writeLn('$prefix1${_commas(args, prefix1.length)}) {');
      writeLn("    if (json['tag'] != '${cons.name}') return null;");
      writeLn("$prefix2${_commas(recArgs, prefix2.length)});");
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

  bool constructorHasUnknownTypes(Constructor cons) {
    bool typesHaveUnknownTypes(Iterable<TypeAppl> types) {
      for (final ty in types) {
        if (isUnknownType(ty)) return true;
        if (typesHaveUnknownTypes(ty.arguments)) return true;
      }
      return false;
    }

    return typesHaveUnknownTypes(cons.parameters.map((p) => p.type));
  }

  bool datatypeHasUnknownTypes(DataTypeDefinition def) {
    return def.constructors.any(constructorHasUnknownTypes);
  }

  Map<String, TypeAppl> substitution(DataTypeDefinition def,
                                     List<TypeAppl> tys) {
    assert(def.variables.length == tys.length);
    final Map<String, TypeAppl> subst = {};
    for (int i = 0; i < def.variables.length; i++) {
      subst[def.variables[i]] = tys[i];
    }
    return subst;
  }

  void _addConstructor(Constructor cons,
                       Set<TypeAppl> seen,
                       Set<TypeAppl> result) {
    for (final type in cons.parameters.map((p) => p.type)) {
      _addDataType(type, seen, result);
    }
  }

  void _addDataType(TypeAppl type,
                    Set<TypeAppl> seen,
                    Set<TypeAppl> result) {
    if (seen.contains(type)) return;
    seen.add(type);
    final datatype = dataTypeMatching(type);
    if (datatype != null) {
      final subst = substitution(datatype, type.arguments);
      for (final cons in datatype.constructors) {
        _addConstructor(cons.subst(subst), seen, result);
      }
    } else if (_isAtom(type)) {
      return;
    } else if (_isList1(type)) {
      _addDataType(type.arguments[0], seen, result);
    } else {
      result.add(type);
    }
  }

  Set<TypeAppl> unknownTypesOfConstructor(Constructor cons) {
    Set<TypeAppl> result = new Set();
    Set<TypeAppl> seen = new Set();
    _addConstructor(cons, seen, result);
    return result;
  }

  Set<TypeAppl> unknownTypesOfDatatype(DataTypeDefinition def) {
    Set<TypeAppl> result = new Set();
    Set<TypeAppl> seen = new Set();
    final args = def.variables.map((v) => new TypeAppl(v, [])).toList();
    _addDataType(new TypeAppl(def.name, args), seen, result);
    return result;
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

    // toJson
    if (config.toJson
        && !def.constructors.isEmpty
        && !overriden(def.name, 'toJson')) {
      writeLn('  Map toJson();');
    }

    // fromJson
    if (config.fromJson
        && !def.constructors.isEmpty
        && !overriden(def.name, 'fromJson')) {
      signature(TypeAppl type) {
        final prefix = def.variables.contains(type.name) ? '' : '${type.name} ';
        return '$prefix${fromJsonFunctionName(type)}(Map json)';
      }

      final args = ['Map json']
        ..addAll(unknownTypesOfDatatype(def).map(signature));
      final prefix = '  static ${def.name} fromJson(';
      writeLn('$prefix${_commas(args, prefix.length)}) =>');
      final indent = '      ';
      final body = def.constructors.map((cons) {
        final args = ['json']
          ..addAll(unknownTypesOfConstructor(cons).map(fromJsonFunctionName));
        return '${cons.name}.fromJson(${_commas(args)})';
      }).join(' ??\n$indent');
      writeLn('$indent$body;');
      writeLn('  }');
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

  void generateLibraryName() {
    if (libraryName.isDefined) {
      writeLn('library ${libraryName.value};');
      writeLn('');
    }
  }

  void generateImports() {
    for (final dependency in imports) {
      writeLn('import "$dependency";');
    }
    bool written = !imports.isEmpty;
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

  void generatePrelude() {
    bool written = false;
    if (config.toJson
        && defs.any((d) => !d.constructors.isEmpty)
        && defs.any((d) => datatypeHasUnknownTypes(d))) {
      writeLn('''_dynamicToJson(value) {
  if (value == null || value is num || value is int || value is double
      || value is bool || value is String) {
    return value;
  } else if (value is List) {
    return value.map(_dynamicToJson).toList();
  } else {
    return value.toJson();
  }
}''');
      written = true;
    }
    if (config.matchMethod) {
      writeLn('''_nonExhaustive() {
  throw "non-exhaustive matching";
}''');
      written = true;
    }
    if (written) {
      writeLn('');
    }
  }

  generate() {
    generateLibraryName();
    generateImports();
    generatePrelude();
    for (final def in defs) {
      generateDefinition(def);
      writeLn('');
    }
  }
}

String generate(Module module, Configuration configuration) {
  StringBuffer buffer = new StringBuffer();
  new Generator(configuration, buffer, module.libraryName, module.imports,
      module.adts, module.classes).generate();
  return buffer.toString();
}
