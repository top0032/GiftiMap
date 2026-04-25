void main() {
  final expirationDate = "2026.05.20";
  final regex = RegExp(r'(\d{4})[./-년\s]*(\d{1,2})[./-월\s]*(\d{1,2})');
  final match = regex.firstMatch(expirationDate);
  
  if (match != null && match.groupCount >= 3) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    
    final expDate = DateTime(year, month, day);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    
    final days = expDate.difference(todayOnly).inDays;
    print("year: $year, month: $month, day: $day");
    print("expDate: $expDate");
    print("todayOnly: $todayOnly");
    print("difference in days: $days");
  } else {
    print("Regex failed");
  }
}