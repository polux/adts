library configuration;

class Configuration {
  final bool finalFields;
  final bool isGetters;
  final bool asGetters;
  final bool copyMethod;
  final bool equality;
  final bool toStringMethod;
  final bool parser;  // WIP
  final bool enumerator;  // WIP
  final bool visitor;
  final bool matchMethod;
  final bool extractor;
  final bool toJson;
  final bool fromJson;

  const Configuration({
    bool finalFields: true,
    bool isGetters: true,
    bool asGetters: true,
    bool copyMethod: true,
    bool equality: true,
    bool toStringMethod: true,
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
     , this.parser = false
     , this.enumerator = false
     , this.visitor = visitor
     , this.matchMethod = matchMethod
     , this.extractor = extractor
     , this.toJson = toJson
     , this.fromJson = fromJson;
}
