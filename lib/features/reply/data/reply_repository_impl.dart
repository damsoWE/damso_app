import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/reply_repository.dart';

/// 실서버 구현(F4). 엔드포인트는 openapi.yaml 확정 후 맞춘다(현재 임시 값).
class ReplyRepositoryImpl implements ReplyRepository {
  ReplyRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> send({required String inquiryId, required String body}) =>
      _dio.post<void>('/inquiries/$inquiryId/replies', data: {'body': body});
}

final replyRepositoryProvider = Provider<ReplyRepository>(
  (ref) => ReplyRepositoryImpl(ref.watch(dioProvider)),
);
