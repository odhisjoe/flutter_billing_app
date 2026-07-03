import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/sale.dart';

abstract class SaleRepository {
  Future<Either<Failure, void>> saveSale(Sale sale);
  Future<Either<Failure, List<Sale>>> getSalesByDateRange(
      DateTime from, DateTime to);
  Future<Either<Failure, List<Sale>>> getAllSales();
}
