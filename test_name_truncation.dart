void main() {
  print('Testing Fighter Name Truncation');
  print('=' * 50);

  final testNames = [
    // Regular names
    'Jon Jones',
    'Max Holloway',
    'Islam Makhachev',

    // Long names
    'Alexander Volkanovski',
    'Khabib Nurmagomedov',
    'Valentina Shevchenko',

    // Very long Brazilian names
    'Jose Aldo da Silva Oliveira Junior',
    'Anderson Silva dos Santos',
    'Ronaldo Souza dos Santos',

    // Single names
    'Khabib',
    'Ngannou',

    // Hyphenated names
    'Rose Namajunas-Barry',
    'Georges St-Pierre',

    // Names with initials
    'T.J. Dillashaw',
    'B.J. Penn',
  ];

  for (final name in testNames) {
    final truncated = truncateFighterName(name);
    final padding = ' ' * (40 - name.length);
    print('$name$padding => $truncated');
  }

  print('\n' + '=' * 50);
  print('Testing Record Formatting');
  print('=' * 50);

  final testRecords = [
    '29-0-0',
    '15-3',
    '15-3-1',
    '',
    null,
    '0-0',
    '100-50-10',
  ];

  for (final record in testRecords) {
    final formatted = formatRecord(record);
    final displayRecord = record ?? 'null';
    final padding = ' ' * (15 - displayRecord.length);
    print('$displayRecord$padding => $formatted');
  }
}

String truncateFighterName(String fullName) {
  const nameMaxLength = 20;

  if (fullName.length <= nameMaxLength) {
    return fullName;
  }

  // Split into parts
  final parts = fullName.split(' ');

  if (parts.length == 1) {
    // Single long name, truncate with ellipsis
    return '${fullName.substring(0, nameMaxLength - 3)}...';
  }

  if (parts.length == 2) {
    // First name + last initial
    final firstName = parts[0];
    final lastInitial = parts[1].isNotEmpty ? parts[1][0] : '';
    return '$firstName $lastInitial.';
  }

  if (parts.length >= 3) {
    // Complex name - try different strategies
    final firstName = parts[0];
    final lastName = parts.last;

    // Try first + last initial
    final firstPlusInitial = '$firstName ${lastName[0]}.';
    if (firstPlusInitial.length <= nameMaxLength) {
      return firstPlusInitial;
    }

    // Just use first name if it fits
    if (firstName.length <= nameMaxLength - 3) {
      return '$firstName...';
    }

    // Truncate first name
    return '${firstName.substring(0, nameMaxLength - 3)}...';
  }

  return fullName;
}

String formatRecord(String? record) {
  if (record == null || record.isEmpty) {
    return '—';
  }

  // Ensure consistent format (XX-X-X)
  final parts = record.split('-');
  if (parts.length >= 2) {
    return record;
  }

  return '—';
}