import '../../../fennec_pg.dart';

abstract class IRepository<T, S> {
  Future<List<T>> findAll({FilterBuilder filterBuilder});
  Future<T?> findOneById(S s);
  Future<T?> insert(T t);
  Future<List<T?>> insertAll(List<T> t);
  Future<T?> deleteOneById(S s, {bool returning = true});
  Future<List<T?>> deleteAll(List<S> s, {bool returning = true});
  Future<T?> updateOneById(S s, T t);
  Future<List<T?>> updateAll(List<Map<S, T>> objects);
  Future<List<T?>> selectOne(SelectBuilder selectBuilder);
  Future<List<T?>> selectAll(SelectBuilder selectBuilder);
}
