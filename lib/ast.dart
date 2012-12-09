// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library ast;

_toString(x) => x.toString();

class DataTypeDefinition {
  String name;
  List<String> variables;
  List<Constructor> constructors;

  DataTypeDefinition(this.name, this.variables, this.constructors);

  String toString() {
    String args = Strings.join(variables, ', ');
    String constrs = Strings.join(constructors.map(_toString), ' | ');
    return "adt $name<$args> = $constrs";
  }
}

class Constructor {
  String name;
  List<Parameter> parameters;

  Constructor(this.name, this.parameters);

  String toString() {
    String params = Strings.join(parameters.map(_toString), ', ');
    return "$name($params)";
  }
}

class Parameter {
  String name;
  TypeAppl type;

  Parameter(this.type, this.name);

  String toString() => "$type $name";
}

class TypeAppl {
  String name;
  List<Type> arguments;

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