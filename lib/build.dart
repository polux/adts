// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library build;

import 'dart:io';
import 'dart:convert' show JSON;
import 'package:adts/adt_parser.dart';
import 'package:adts/generator.dart';
import 'package:args/args.dart';

void build(List<String> arguments) {
  final args = _processArgs(arguments);
  final changedFiles = args["changed"];
  final removedFiles = args["removed"];
  final cleanBuild = args["clean"];
  final machineFormat = args["machine"];
  // Also trigger a full build if the script was run from the command line
  // with no arguments
  final fullBuild = args["full"] || (!machineFormat && changedFiles.isEmpty &&
      removedFiles.isEmpty && !cleanBuild);

  changedFiles.where(_isAdartFilename).forEach(_compileADartFile);
  removedFiles.forEach(_handleRemovedFile);
}

void _compileADartFile(String sourceName) {
  assert(_isAdartFilename(sourceName));
  final source = new File(sourceName);
  final targetName = _adartToDart(sourceName);
  final target = new File(targetName);
  final parseResult = moduleParser.run(source.readAsStringSync());
  if (parseResult.isSuccess) {
    final generated = generate(parseResult.value, new Configuration());
    target.writeAsStringSync(generated);
    _reportMapping(sourceName, targetName);
  } else {
    if (target.existsSync()) {
      target.deleteSync();
    }
    final position = parseResult.expectations.position;
    final message = parseResult.errorMessage;
    if (position.offset >= parseResult.text.length) {
      _reportErrorForLine(sourceName, position.line, message);
    } else {
      _reportErrorForOffset(sourceName, position.offset, message);
    }
  }
}

void _handleRemovedFile(String filename) {
  if (_isAdartFilename(filename)) {
    final target = new File(_adartToDart(filename));
    if (target.existsSync()) {
      target.deleteSync();
    }
  } else if (_isDartFilename(filename)) {
    final sourceName = _dartToADart(filename);
    final source = new File(sourceName);
    if (source.existsSync()) {
      _compileADartFile(sourceName);
    }
  }
}

void _reportErrorForLine(String fileName, int line, String message) {
  final result = {
    'method': 'error',
    'params': {
      'file': fileName,
      'line': line,
      'message': message
    }
  };
  print(JSON.encode([result]));
}

void _reportErrorForOffset(String fileName, int offset, String message) {
  final result = {
    'method': 'error',
    'params': {
      'file': fileName,
      'charStart': offset,
      'charEnd': offset + 1,
      'message': message
    }
  };
  print(JSON.encode([result]));
}

void _reportMapping(String source, String target) {
  final result = {
    'method': 'mapping',
    'params': {
      'from': source,
      'to': target
    }
  };
  print(JSON.encode([result]));
}

bool _isAdartFilename(String filename) => filename.endsWith(".adart");
bool _isDartFilename(String filename) => filename.endsWith(".dart");

String _adartToDart(String filename) {
  assert(_isAdartFilename(filename));
  return filename.replaceFirst(new RegExp(r"adart$"), "dart");
}

String _dartToADart(String filename) {
  assert(_isDartFilename(filename));
  return filename.replaceFirst(new RegExp(r"dart$"), "adart");
}

ArgResults _processArgs(List<String> arguments) {
  var parser = new ArgParser()
    ..addOption("changed", help: "the file has changed since the last build",
        allowMultiple: true)
    ..addOption("removed", help: "the file was removed since the last build",
        allowMultiple: true)
    ..addFlag("clean", negatable: false, help: "remove any build artifacts")
    ..addFlag("full", negatable: false, help: "perform a full build")
    ..addFlag("machine", negatable: false,
        help: "produce warnings in a machine parseable format");
  return parser.parse(arguments);
}