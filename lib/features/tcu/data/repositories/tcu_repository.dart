import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';
import 'package:seddo/features/tcu/data/services/public_transport_service.dart';

abstract class TcuRepository {
  Future<List<TcuRouteOption>> getRouteOptions({
    String origin = 'Fann Hock',
    String destination = 'Liberté 6',
    TcuTransportType filter = TcuTransportType.all,
  });
}

class TcuRepositoryImpl implements TcuRepository {
  final PublicTransportService _service;

  TcuRepositoryImpl({
    PublicTransportService? service,
  }) : _service = service ?? PublicTransportService();

  @override
  Future<List<TcuRouteOption>> getRouteOptions({
    String origin = 'Fann Hock',
    String destination = 'Liberté 6',
    TcuTransportType filter = TcuTransportType.all,
  }) {
    return _service.getRouteOptions(
      origin: origin,
      destination: destination,
      filter: filter,
    );
  }
}
