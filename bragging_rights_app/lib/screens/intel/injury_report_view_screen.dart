import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/intel_card_model.dart';
import '../../models/injury_model.dart';
import '../../services/injury_service.dart';

class InjuryReportViewScreen extends StatefulWidget {
  final UserIntelCard userCard;
  final String cardType; // 'home', 'away', or 'bundle'
  final String? homeTeamId;
  final String? awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final String sport;

  const InjuryReportViewScreen({
    Key? key,
    required this.userCard,
    required this.cardType,
    this.homeTeamId,
    this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.sport,
  }) : super(key: key);

  @override
  State<InjuryReportViewScreen> createState() => _InjuryReportViewScreenState();
}

class _InjuryReportViewScreenState extends State<InjuryReportViewScreen> {
  bool _isLoading = true;
  GameInjuryReport? _report;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInjuryData();
  }

  Future<void> _loadInjuryData() async {
    // Check if data is cached in user card
    if (widget.userCard.injuryData != null) {
      setState(() {
        _report = widget.userCard.injuryData;
        _isLoading = false;
      });
      return;
    }

    // Fetch fresh injury data
    if (widget.homeTeamId == null || widget.awayTeamId == null) {
      setState(() {
        _errorMessage = 'Missing team information';
        _isLoading = false;
      });
      return;
    }

    try {
      final injuryService = InjuryService();
      final report = await injuryService.getGameInjuries(
        sport: widget.sport,
        homeTeamId: widget.homeTeamId!,
        homeTeamName: widget.homeTeamName,
        awayTeamId: widget.awayTeamId!,
        awayTeamName: widget.awayTeamName,
      );

      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading injury data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTitle(),
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Complete Report',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryCyan),
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildOwnershipBadge(),
                    Expanded(
                      child: _report != null
                          ? _buildInjuryReport()
                          : _buildNoDataState(),
                    ),
                  ],
                ),
    );
  }

  String _getTitle() {
    if (widget.cardType == 'bundle') {
      return 'Full Game Injury Intel';
    } else if (widget.cardType == 'home') {
      return '${widget.homeTeamName} Injury Intel';
    } else {
      return '${widget.awayTeamName} Injury Intel';
    }
  }

  Widget _buildOwnershipBadge() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.deepBlue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Owned - Purchased for ${widget.userCard.brSpent} BR',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInjuryReport() {
    if (_report == null) return _buildNoDataState();

    final showHomeTeam = widget.cardType == 'bundle' || widget.cardType == 'home';
    final showAwayTeam = widget.cardType == 'bundle' || widget.cardType == 'away';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Report Header
        Row(
          children: [
            const Icon(Icons.healing, color: Color(0xFFFF4B4B), size: 20),
            const SizedBox(width: 8),
            const Text(
              'COMPLETE INJURY REPORT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF4B4B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Home Team Injuries
        if (showHomeTeam) ...[
          _buildTeamSection(
            teamName: _report!.homeTeamName,
            teamIcon: '🟣', // TODO: Use actual logo
            injuries: _report!.homeInjuries,
          ),
          const SizedBox(height: 16),
        ],

        // Away Team Injuries
        if (showAwayTeam) ...[
          _buildTeamSection(
            teamName: _report!.awayTeamName,
            teamIcon: '🔵', // TODO: Use actual logo
            injuries: _report!.awayInjuries,
          ),
          const SizedBox(height: 16),
        ],

        // Intel Insight (only for bundle)
        if (widget.cardType == 'bundle' && _report!.hasSignificantInjuries)
          _buildIntelInsight(),
      ],
    );
  }

  Widget _buildTeamSection({
    required String teamName,
    required String teamIcon,
    required List<Injury> injuries,
  }) {
    if (injuries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryCyan.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Text(teamIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No injuries reported',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: Color(0xFF00FF88),
              size: 24,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(teamIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              teamName.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...injuries.map((injury) => _buildInjuryItem(injury)).toList(),
      ],
    );
  }

  Widget _buildInjuryItem(Injury injury) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B4B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4B4B).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  injury.athleteName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildStatusBadge(injury.status),
            ],
          ),
          const SizedBox(height: 8),
          if (injury.details != null) ...[
            Row(
              children: [
                const Icon(Icons.medical_services, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  injury.details!.injuryDescription,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (injury.details?.returnDate != null) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Expected Return: ${_formatDate(injury.details!.returnDate!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (injury.longComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${injury.longComment}"',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    String displayText = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'out':
        backgroundColor = const Color(0xFFFF4B4B);
        break;
      case 'questionable':
        backgroundColor = AppTheme.warningAmber;
        break;
      case 'doubtful':
        backgroundColor = AppTheme.warningAmber;
        break;
      default:
        backgroundColor = AppTheme.primaryCyan;
        displayText = 'DAY-TO-DAY';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIntelInsight() {
    if (_report == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningAmber.withOpacity(0.1),
            AppTheme.warningAmber.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningAmber.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'INTEL INSIGHT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningAmber,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _report!.insightText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Injury Impact Score: ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
              Text(
                '${_report!.homeTeamName}: ${_report!.homeImpactScore.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _report!.homeImpactScore > 5 ? const Color(0xFFFF4B4B) : const Color(0xFF00FF88),
                ),
              ),
              const Text(
                ' | ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
              Text(
                '${_report!.awayTeamName}: ${_report!.awayImpactScore.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _report!.awayImpactScore > 5 ? const Color(0xFFFF4B4B) : const Color(0xFF00FF88),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.healing,
            size: 64,
            color: Colors.white30,
          ),
          const SizedBox(height: 16),
          const Text(
            'No injury data available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Color(0xFFFF4B4B),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Error loading injury data',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadInjuryData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
