import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/fighter_data_service.dart';
import '../../models/fighter_model.dart';

class FighterDetailsScreen extends StatefulWidget {
  final String fighterId;
  final String fighterName;
  final String? record;
  final String sport;
  final String? espnId;

  const FighterDetailsScreen({
    Key? key,
    required this.fighterId,
    required this.fighterName,
    this.record,
    required this.sport,
    this.espnId,
  }) : super(key: key);

  @override
  State<FighterDetailsScreen> createState() => _FighterDetailsScreenState();
}

class _FighterDetailsScreenState extends State<FighterDetailsScreen> {
  final FighterDataService _fighterService = FighterDataService();
  FighterData? _fighterData;
  FighterModel? _fighter;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFighterDetails();
  }

  Future<void> _loadFighterDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Try to get fighter data from Firestore cache or ESPN
      final fighterData = await _fighterService.getFighterData(
        fighterId: widget.fighterId,
        fighterName: widget.fighterName,
        espnId: widget.espnId ?? widget.fighterId, // Use fighterId as espnId if not provided
        forceRefresh: false,
      );

      if (mounted) {
        if (fighterData != null) {
          setState(() {
            _fighterData = fighterData;
            // Convert FighterData to FighterModel for compatibility
            _fighter = _convertToFighterModel(fighterData);
            _isLoading = false;
          });
        } else {
          setState(() {
            // Create a basic fighter model if no data available
            _fighter = FighterModel(
              id: widget.fighterId,
              name: widget.fighterName,
              record: widget.record,
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load fighter details';
          _isLoading = false;
        });
      }
    }
  }

  FighterModel _convertToFighterModel(FighterData data) {
    return FighterModel(
      id: data.id,
      name: data.name,
      nickname: data.nickname,
      record: data.formattedRecord,
      wins: data.wins,
      losses: data.losses,
      draws: data.draws,
      knockouts: data.kos,
      submissions: data.submissions,
      decisions: data.decisions,
      height: _formatHeight(data),
      weight: data.weightClass,
      reach: data.reach != null ? '${data.reach}"' : null,
      stance: data.stance,
      age: data.age,
      imageUrl: data.headshotUrl,
      flagUrl: data.flagUrl,
      division: data.weightClass,
    );
  }

  String? _formatHeight(FighterData data) {
    // Convert height from inches to feet'inches" format if needed
    if (data.reach != null) {
      // Assuming reach is in inches, convert to display format
      return null; // ESPN data doesn't provide height separately
    }
    return null;
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
        title: Text(
          widget.fighterName,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildFighterDetails(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadFighterDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFighterDetails() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Fighter Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryCyan.withOpacity(0.2),
                  AppTheme.deepBlue,
                ],
              ),
            ),
            child: Column(
              children: [
                // Fighter Avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryCyan,
                      width: 3,
                    ),
                    color: AppTheme.surfaceBlue,
                  ),
                  child: _fighter?.imageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _fighter!.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              size: 60,
                              color: AppTheme.primaryCyan,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 60,
                          color: AppTheme.primaryCyan,
                        ),
                ),
                const SizedBox(height: 16),

                // Fighter Name & Nickname
                Text(
                  _fighter?.name ?? widget.fighterName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_fighter?.nickname != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${_fighter!.nickname}"',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                // Record
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBlue,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.borderCyan.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _fighter?.record ?? widget.record ?? 'Record not available',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Country Flag
                if (_fighter?.country != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_fighter?.flagUrl != null)
                        Image.network(
                          _fighter!.flagUrl!,
                          width: 24,
                          height: 16,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _fighter!.country!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Fighter Stats Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Physical Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(),

                const SizedBox(height: 32),

                const Text(
                  'Fight Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFightStats(),

                if (_fighter?.recentFights != null &&
                    _fighter!.recentFights!.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'Recent Fights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentFights(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: PhosphorIconsRegular.ruler,
                  label: 'Height',
                  value: _fighter?.height ?? 'N/A',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppTheme.borderCyan.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: PhosphorIconsRegular.scales,
                  label: 'Weight',
                  value: _fighter?.weight ?? 'N/A',
                ),
              ),
            ],
          ),
          Divider(
            height: 32,
            color: AppTheme.borderCyan.withOpacity(0.3),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: PhosphorIconsRegular.arrowsHorizontal,
                  label: 'Reach',
                  value: _fighter?.reach ?? 'N/A',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppTheme.borderCyan.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: PhosphorIconsRegular.person,
                  label: 'Stance',
                  value: _fighter?.stance ?? 'N/A',
                ),
              ),
            ],
          ),
          Divider(
            height: 32,
            color: AppTheme.borderCyan.withOpacity(0.3),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: PhosphorIconsRegular.calendar,
                  label: 'Age',
                  value: _fighter?.age?.toString() ?? 'N/A',
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppTheme.borderCyan.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: PhosphorIconsRegular.mapPin,
                  label: 'Division',
                  value: _fighter?.division ?? 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryCyan,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFightStats() {
    final wins = _fighter?.wins ?? 0;
    final losses = _fighter?.losses ?? 0;
    final draws = _fighter?.draws ?? 0;
    final knockouts = _fighter?.knockouts ?? 0;
    final submissions = _fighter?.submissions ?? 0;
    final decisions = _fighter?.decisions ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Win/Loss/Draw
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRecordStat('Wins', wins, Colors.green),
              _buildRecordStat('Losses', losses, Colors.red),
              _buildRecordStat('Draws', draws, Colors.grey),
            ],
          ),

          if (knockouts > 0 || submissions > 0 || decisions > 0) ...[
            const SizedBox(height: 24),
            Divider(
              color: AppTheme.borderCyan.withOpacity(0.3),
            ),
            const SizedBox(height: 24),

            // Win Methods
            const Text(
              'Win Methods',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWinMethod('KO/TKO', knockouts),
                _buildWinMethod('Submission', submissions),
                _buildWinMethod('Decision', decisions),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordStat(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildWinMethod(String method, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          method,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFights() {
    return Column(
      children: _fighter!.recentFights!.map((fight) {
        final isWin = fight['result'] == 'W';
        final isLoss = fight['result'] == 'L';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWin
                  ? Colors.green.withOpacity(0.3)
                  : isLoss
                      ? Colors.red.withOpacity(0.3)
                      : AppTheme.borderCyan.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWin
                      ? Colors.green.withOpacity(0.2)
                      : isLoss
                          ? Colors.red.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                ),
                child: Center(
                  child: Text(
                    fight['result'] ?? 'N',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isWin
                          ? Colors.green
                          : isLoss
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fight['opponent'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fight['method'] ?? 'Unknown'} • ${fight['round'] ?? 'R?'} • ${fight['date'] ?? 'Date unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}