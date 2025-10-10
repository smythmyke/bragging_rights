import 'package:flutter/material.dart';
import '../edge_card_types.dart';
import 'edge_card_base.dart';

/// Weather Impact Card
/// Displays weather conditions with betting suggestions
class WeatherImpactCard extends StatelessWidget {
  final EdgeCardData cardData;
  final VoidCallback onPurchase;
  final bool showFullContent;

  const WeatherImpactCard({
    Key? key,
    required this.cardData,
    required this.onPurchase,
    this.showFullContent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EdgeCardBase(
      cardData: cardData,
      onPurchase: onPurchase,
      showFullContent: showFullContent,
      contentBuilder: _buildContent,
    );
  }

  Widget _buildContent(BuildContext context, EdgeCardData cardData) {
    final temperature = cardData.metadata['temperature'];
    final conditions = cardData.metadata['conditions'];
    final windSpeed = cardData.metadata['windSpeed'];
    final windDirection = cardData.metadata['windDirection'];

    // Parse additional details from fullContent
    final sections = _parseWeatherContent(cardData.fullContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.cloud,
              color: Colors.lightBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Weather Conditions',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Weather metrics grid
        _buildWeatherGrid(temperature, windSpeed, windDirection, conditions),

        const SizedBox(height: 16),

        // Impact analysis
        if (sections['impact'] != null && sections['impact']!.isNotEmpty) ...[
          _buildImpactAnalysis(sections['impact']!),
          const SizedBox(height: 12),
        ],

        // Betting suggestion
        if (sections['suggestion'] != null && sections['suggestion']!.isNotEmpty)
          _buildBettingSuggestion(sections['suggestion']!),
      ],
    );
  }

  Map<String, List<String>> _parseWeatherContent(String content) {
    final sections = <String, List<String>>{
      'impact': [],
      'suggestion': [],
    };

    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.contains('IMPACT ANALYSIS')) {
        currentSection = 'impact';
      } else if (trimmed.contains('BETTING SUGGESTION')) {
        currentSection = 'suggestion';
      } else if (trimmed.startsWith('•')) {
        final text = trimmed.replaceFirst('•', '').trim();
        if (currentSection != null && text.isNotEmpty) {
          sections[currentSection]!.add(text);
        }
      } else if (currentSection != null && !trimmed.contains('WEATHER IMPACT')) {
        // Add non-bullet lines as well
        if (!trimmed.startsWith('🌡️') &&
            !trimmed.startsWith('🌬️') &&
            !trimmed.startsWith('☁️') &&
            trimmed.isNotEmpty) {
          sections[currentSection]!.add(trimmed);
        }
      }
    }

    return sections;
  }

  Widget _buildWeatherGrid(
    dynamic temperature,
    dynamic windSpeed,
    dynamic windDirection,
    dynamic conditions,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.lightBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Temperature and Conditions row
          Row(
            children: [
              // Temperature
              Expanded(
                child: _buildWeatherStat(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: temperature != null ? '${temperature}°F' : 'N/A',
                  color: _getTemperatureColor(temperature),
                ),
              ),

              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),

              // Conditions
              Expanded(
                child: _buildWeatherStat(
                  icon: Icons.wb_sunny,
                  label: 'Conditions',
                  value: conditions?.toString() ?? 'Unknown',
                  color: Colors.amber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Wind row
          if (windSpeed != null)
            _buildWindInfo(windSpeed, windDirection),
        ],
      ),
    );
  }

  Widget _buildWeatherStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWindInfo(dynamic windSpeed, dynamic windDirection) {
    final speed = windSpeed is int ? windSpeed : int.tryParse(windSpeed.toString()) ?? 0;
    final direction = windDirection?.toString() ?? '';

    // Determine wind severity
    Color windColor;
    String windSeverity;
    if (speed >= 20) {
      windColor = Colors.red;
      windSeverity = 'EXTREME';
    } else if (speed >= 15) {
      windColor = Colors.orange;
      windSeverity = 'HIGH';
    } else if (speed >= 10) {
      windColor = Colors.yellow;
      windSeverity = 'MODERATE';
    } else {
      windColor = Colors.green;
      windSeverity = 'LOW';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: windColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: windColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.air, color: windColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Wind: ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$speed mph ',
                      style: TextStyle(
                        color: windColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (direction.isNotEmpty)
                      Text(
                        direction,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$windSeverity IMPACT',
                  style: TextStyle(
                    color: windColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactAnalysis(List<String> impacts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: Colors.lightBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'IMPACT ANALYSIS',
                style: TextStyle(
                  color: Colors.lightBlue.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...impacts.map((impact) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        impact,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBettingSuggestion(List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb,
                color: Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'BETTING SUGGESTION',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Color _getTemperatureColor(dynamic temperature) {
    if (temperature == null) return Colors.grey;

    final temp = temperature is int ? temperature : int.tryParse(temperature.toString()) ?? 70;

    if (temp >= 90) {
      return Colors.red;
    } else if (temp >= 75) {
      return Colors.orange;
    } else if (temp >= 50) {
      return Colors.green;
    } else if (temp >= 32) {
      return Colors.lightBlue;
    } else {
      return Colors.blue;
    }
  }
}
