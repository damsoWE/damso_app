import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inquiry/presentation/teacher/home_inquiry_section.dart';
import '../../notification/presentation/device_registrar.dart';

/// F3-4 교사 홈 (Figma 216-5567). 확인 전 긴급 카드와 최근 문의(F2 FR-021).
/// 마이페이지는 하단 탭으로 간다. 처음 들어오면 기기 알림 권한을 묻는다(FR-031a).
class TeacherHomePage extends ConsumerStatefulWidget {
  const TeacherHomePage({super.key});

  @override
  ConsumerState<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends ConsumerState<TeacherHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(deviceRegistrarProvider).requestPermissionIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('교사 홈')),
      body: const TeacherHomeInquirySection(),
    );
  }
}
