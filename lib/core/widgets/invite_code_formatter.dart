import 'package:flutter/services.dart';

import '../validation/validators.dart';

/// 초대 코드 입력: 공백 제거·대문자 변환·10자 제한(spec Edge Case). 가입·자녀 추가가 함께 쓴다.
class InviteCodeFormatter extends TextInputFormatter {
  const InviteCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = normalizeInviteCode(newValue.text);
    if (text.length > 10) text = text.substring(0, 10);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
