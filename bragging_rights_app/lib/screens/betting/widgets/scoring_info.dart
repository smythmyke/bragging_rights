import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ScoringInfo extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;

  const ScoringInfo({
    Key? key,
    this.isExpanded = false,
    this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryCyan.withOpacity(0.1),
            AppTheme.primaryCyan.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.neonGlow(
          color: AppTheme.primaryCyan,
          intensity: 0.1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 18,
                      color: AppTheme.warningAmber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'POINT SCORING SYSTEM',
                    style: TextStyle(
                      color: AppTheme.primaryCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.primaryCyan.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              height: 1,
              color: AppTheme.primaryCyan.withOpacity(0.2),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildScoringRule(
                    'Correct Winner',
                    '+10 pts',
                    Icons.person,
                    AppTheme.neonGreen,
                  ),
                  const SizedBox(height: 8),
                  _buildScoringRule(
                    'Correct Method (KO/TKO, SUB, DEC)',
                    '+5 pts',
                    Icons.sports_mma,
                    AppTheme.primaryCyan,
                  ),
                  const SizedBox(height: 8),
                  _buildScoringRule(
                    'Correct Round',
                    '+5 pts',
                    Icons.access_time,
                    AppTheme.secondaryCyan,
                  ),
                  const SizedBox(height: 8),
                  _buildScoringRule(
                    'Underdog Win Bonus',
                    '+10 pts',
                    Icons.trending_up,
                    AppTheme.warningAmber,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withOpacity(0.1),
                      border: Border.all(
                        color: AppTheme.warningAmber.withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: AppTheme.warningAmber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Maximum per fight: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '30 points',
                          style: TextStyle(
                            color: AppTheme.warningAmber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoringRule(String description, String points, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            points,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}