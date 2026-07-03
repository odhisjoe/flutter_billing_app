import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../models/sale_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  @override
  Future<Either<Failure, void>> saveSale(Sale sale) async {
    try {
      final box = HiveDatabase.salesBox;
      final model = SaleModel.fromEntity(sale);
      await box.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getSalesByDateRange(
      DateTime from, DateTime to) async {
    try {
      final box = HiveDatabase.salesBox;
      final sales = box.values.where((s) {
        return s.date.isAfter(from.subtract(const Duration(days: 1))) &&
            s.date.isBefore(to.add(const Duration(days: 1)));
      }).toList();
      sales.sort((a, b) => b.date.compareTo(a.date));
      return Right(sales.map((s) => s.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getAllSales() async {
    try {
      final box = HiveDatabase.salesBox;
      final sales = box.values.toList();
      sales.sort((a, b) => b.date.compareTo(a.date));
      return Right(sales.map((s) => s.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
