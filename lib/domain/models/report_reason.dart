enum ReportReason {
  spam('spam', '垃圾内容'),
  harassment('harassment', '攻击或骚扰'),
  inappropriate('inappropriate', '不适当内容'),
  privacy('privacy', '泄露隐私'),
  other('other', '其他');

  const ReportReason(this.value, this.label);

  final String value;
  final String label;
}
