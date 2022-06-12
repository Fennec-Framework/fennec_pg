import 'dart:mirrors';

import '../migrations.dart';
import '../relations.dart';

abstract class Serializable {
  Map<String, dynamic> serializeModel() {
    Map<String, dynamic> map = {};
    InstanceMirror im = reflect(this);
    ClassMirror cm = im.type;
    var decls = cm.declarations.values.whereType<VariableMirror>();
    for (var dm in decls) {
      if (dm.metadata.isNotEmpty) {
        for (var meta in dm.metadata) {
          if (meta.reflectee is Column && meta.reflectee is! PrimaryKey) {
            InstanceMirror cm = reflect(meta.reflectee);
            String? alias = cm.getField(#alias).reflectee;
            Type? serializableTo = cm.getField(#serializableTo).reflectee;
            Type type = serializableTo ?? dm.type.reflectedType;
            var key = alias ?? MirrorSystem.getName(dm.simpleName);
            if (im.getField(dm.simpleName).reflectee != null) {
              if (type == int) {
                var val =
                    int.parse(im.getField(dm.simpleName).reflectee.toString());
                map[key] = val;
              } else if (type == double) {
                var val = double.parse(
                    im.getField(dm.simpleName).reflectee.toString());
                map[key] = val;
              } else if (type == num) {
                var val =
                    num.parse(im.getField(dm.simpleName).reflectee.toString());
                map[key] = val;
              } else if (type == bool) {
                var val = im.getField(dm.simpleName).reflectee as bool;
                map[key] = val;
              } else if (type == String) {
                var val = im.getField(dm.simpleName).reflectee.toString();
                map[key] = val;
              } else if (type == List) {
                map[key] = List.from(im.getField(dm.simpleName).reflectee);
              } else if (type == Map) {
                map[key] = Map.from(im.getField(dm.simpleName).reflectee);
              } else {
                map[key] = im.getField(dm.simpleName).reflectee;
              }
            } else {
              map[key] = im.getField(dm.simpleName).reflectee;
            }
          }
        }
      } else {
        Type type = dm.type.reflectedType;
        var key = MirrorSystem.getName(dm.simpleName);
        if (type == int) {
          var val = int.parse(im.getField(dm.simpleName).reflectee.toString());
          map[key] = val;
        } else if (type == double) {
          var val =
              double.parse(im.getField(dm.simpleName).reflectee.toString());
          map[key] = val;
        } else if (type == num) {
          var val = num.parse(im.getField(dm.simpleName).reflectee.toString());
          map[key] = val;
        } else if (type == bool) {
          var val = im.getField(dm.simpleName).reflectee as bool;
          map[key] = val;
        } else if (type == String) {
          var val = im.getField(dm.simpleName).reflectee.toString();
          map[key] = val;
        } else if (type == List) {
          map[key] = List.from(im.getField(dm.simpleName).reflectee);
        } else if (type == Map) {
          map[key] = Map.from(im.getField(dm.simpleName).reflectee);
        } else {
          map[key] = im.getField(dm.simpleName).reflectee;
        }
      }
    }

    return map;
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = {};
    InstanceMirror im = reflect(this);

    ClassMirror cm = im.type;
    var decls = cm.declarations.values.whereType<VariableMirror>();
    for (var dm in decls) {
      if (dm.metadata.isNotEmpty) {
        for (var meta in dm.metadata) {
          if (meta.reflectee is Column) {
            InstanceMirror cm = reflect(meta.reflectee);
            bool serializable = cm.getField(#serializable).reflectee;
            if (serializable) {
              String? alias = cm.getField(#alias).reflectee;
              Type? serializableTo = cm.getField(#serializableTo).reflectee;
              Type type = serializableTo ?? dm.type.reflectedType;
              var key = alias ?? MirrorSystem.getName(dm.simpleName);
              if (im.getField(dm.simpleName).reflectee != null) {
                if (type == int) {
                  var val = int.parse(
                      im.getField(dm.simpleName).reflectee.toString());
                  map[key] = val;
                } else if (type == double) {
                  var val = double.parse(
                      im.getField(dm.simpleName).reflectee.toString());
                  map[key] = val;
                } else if (type == num) {
                  var val = num.parse(
                      im.getField(dm.simpleName).reflectee.toString());
                  map[key] = val;
                } else if (type == bool) {
                  var val = im.getField(dm.simpleName).reflectee as bool;
                  map[key] = val;
                } else if (type == String) {
                  var val = im.getField(dm.simpleName).reflectee.toString();
                  map[key] = val;
                } else if (type == List) {
                  map[key] = List.from(im.getField(dm.simpleName).reflectee);
                } else if (type == Map) {
                  map[key] = Map.from(im.getField(dm.simpleName).reflectee);
                } else {
                  map[key] = im.getField(dm.simpleName).reflectee;
                }
              } else {
                map[key] = im.getField(dm.simpleName).reflectee;
              }
            }
          } else if (meta.reflectee is Relationship) {
            InstanceMirror cm = reflect(meta.reflectee);
            LoadType loadType = cm.getField(#loadType).reflectee;
            if (loadType == LoadType.include) {
              var key = MirrorSystem.getName(dm.simpleName);

              if (im.getField(dm.simpleName).reflectee != null) {
                if (im.getField(dm.simpleName).reflectee is! Iterable) {
                  map[key] = im.getField(dm.simpleName).reflectee.toJson();
                } else if (im.getField(dm.simpleName).reflectee is Set) {
                  Set set = im.getField(dm.simpleName).reflectee;
                  Set<Map<String, dynamic>> result = {};
                  for (var element in set) {
                    result.add(element.toJson());
                  }
                  map[key] = result;
                } else if (im.getField(dm.simpleName).reflectee is List) {
                  List list = im.getField(dm.simpleName).reflectee;
                  List<Map<String, dynamic>> result = [];
                  for (var element in list) {
                    result.add(element.toJson());
                  }
                  map[key] = result;
                }
              }
            }
          } else {
            Type type = dm.type.reflectedType;
            var key = MirrorSystem.getName(dm.simpleName);

            if (type == int) {
              var val =
                  int.parse(im.getField(dm.simpleName).reflectee.toString());
              map[key] = val;
            } else if (type == double) {
              var val =
                  double.parse(im.getField(dm.simpleName).reflectee.toString());
              map[key] = val;
            } else if (type == num) {
              var val =
                  num.parse(im.getField(dm.simpleName).reflectee.toString());
              map[key] = val;
            } else if (type == bool) {
              var val = im.getField(dm.simpleName).reflectee as bool;
              map[key] = val;
            } else if (type == String) {
              var val = im.getField(dm.simpleName).reflectee.toString();
              map[key] = val;
            } else if (type == List) {
              map[key] = List.from(im.getField(dm.simpleName).reflectee);
            } else if (type == Map) {
              map[key] = Map.from(im.getField(dm.simpleName).reflectee);
            } else {
              map[key] = im.getField(dm.simpleName).reflectee;
            }
          }
        }
      } else {
        Type type = dm.type.reflectedType;
        var key = MirrorSystem.getName(dm.simpleName);
        if (type == int) {
          var val = int.parse(im.getField(dm.simpleName).reflectee.toString());
          map[key] = val;
        } else if (type == double) {
          var val =
              double.parse(im.getField(dm.simpleName).reflectee.toString());
          map[key] = val;
        } else if (type == num) {
          var val = num.parse(im.getField(dm.simpleName).reflectee.toString());
          map[key] = val;
        } else if (type == bool) {
          var val = im.getField(dm.simpleName).reflectee as bool;
          map[key] = val;
        } else if (type == String) {
          var val = im.getField(dm.simpleName).reflectee.toString();
          map[key] = val;
        } else if (type == List) {
          map[key] = List.from(im.getField(dm.simpleName).reflectee);
        } else if (type == Map) {
          map[key] = Map.from(im.getField(dm.simpleName).reflectee);
        } else {
          map[key] = im.getField(dm.simpleName).reflectee;
        }
      }
    }
    return map;
  }
}
