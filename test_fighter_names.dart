import 'bragging_rights_app/lib/screens/betting/widgets/fighter_card_constants.dart';

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
    final truncated = FighterCardTextUtils.truncateFighterName(name);
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
    final formatted = FighterCardTextUtils.formatRecord(record);
    final displayRecord = record ?? 'null';
    final padding = ' ' * (15 - displayRecord.length);
    print('$displayRecord$padding => $formatted');
  }
}