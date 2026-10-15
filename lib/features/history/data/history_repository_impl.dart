import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/history_repository.dart';

/// 실서버 구현(F5). 엔드포인트는 openapi.yaml 확정 후 맞춘다(현재 임시 값).
class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<String>> listEntryIds(String inquiryId) async {
    final res = await _dio.get<List<dynamic>>('/inquiries/$inquiryId/history');
    return res.data!.cast<String>();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepositoryImpl(ref.watch(dioProvider)),
);
