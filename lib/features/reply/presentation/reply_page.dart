import 'package:flutter/material.dart';

/// 답변 작성·점검·전송 화면 자리표시(F4 spec 에서 정의).
class ReplyPage extends StatelessWidget {
  const ReplyPage({super.key, required this.inquiryId});

  final String inquiryId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('답변 작성')));
}
