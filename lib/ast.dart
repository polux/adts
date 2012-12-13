// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library ast;

import 'package:persistent/persistent.dart';

_toString(x) => x.toString();

class Module {
  final List<DataTypeDefinition> adts;
  final List<Class> classes;

  Module(this.adts, this.classes);

  String toString() {
    return 'Module($adts, $classes)';
  }
}

class DataTypeDefinition {
  final String name;
  final List<String> variables;
  final List<Constructor> constructors;

  DataTypeDefinition(this.name, this.variables, this.constructors);

  String toString() {
    String args = Strings.join(variables, ', ');
    String constrs = Strings.join(constructors.map(_toString), ' | ');
    return "adt $name<$args> = $constrs";
  }
}

class Constructor {
  final String name;
  final List<Parameter> parameters;

  Constructor(this.name, this.parameters);

  String toString() {
    String params = Strings.join(parameters.map(_toString), ', ');
    return "$name($params)";
  }
}

class Parameter {
  final String name;
  final TypeAppl type;

  Parameter(this.type, this.name);

  String toString() => "$type $name";
}

class TypeAppl {
  final String name;
  final List<Type> arguments;

  TypeAppl(this.name, this.arguments);

  // Warning: the generator depends on this behavior
  String toString() {
    if (arguments.isEmpty) return name;
    else {
      String args = Strings.join(arguments.map(_toString), ', ');
      return "$name<$args>";
    }
  }
}

class Class {
  final String name;
  Map<String,Method> methods;

  Class(this.name, methods) {
    this.methods = {};
    for (final m in methods) {
      this.methods[m.name] = m;
    }
  }

  String toString() {
    return 'Class($name, $methods)';
  }
}


class Method {
  final String name;
  final String text;

  Method(this.name, this.text);

  toString() => 'Method($name, $text)';
}