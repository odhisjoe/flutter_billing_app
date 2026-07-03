import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/sale.dart';
import '../repositories/sale_repository.dart';

class SaveSaleUseCase implements UseCase<void, Sale> {
  final SaleRepository repository;

  SaveSaleUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Sale params) {
    return repository.saveSale(params);
  }
}

class GetSalesByDateRangeUseCase
    implements UseCase<List<Sale>, DateRangeParams> {
  final SaleRepository repository;

  GetSalesByDateRangeUseCase(this.repository);

  @override
  Future<Either<Failure, List<Sale>>> call(DateRangeParams params) {
    return repository.getSalesByDateRange(params.from, params.to);
  }
}

class GetAllSalesUseCase implements UseCase<List<Sale>, NoParams> {
  final SaleRepository repository;

  GetAllSalesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Sale>>> call(NoParams params) {
    return repository.getAllSales();
  }
}

class DateRangeParams {
  final DateTime from;
  final DateTime to;

  const DateRangeParams({required this.from, required this.to});
}
