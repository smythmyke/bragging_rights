import 'package:flutter/material.dart';
import '../../services/wager_service.dart';
import '../../widgets/br_app_bar.dart';
import 'package:intl/intl.dart';

class ActiveWagersScreen extends StatefulWidget {
  const ActiveWagersScreen({super.key});

  @override
  State<ActiveWagersScreen> createState() => _ActiveWagersScreenState();
}

class _ActiveWagersScreenState extends State<ActiveWagersScreen>
    with SingleTickerProviderStateMixin {
  final WagerService _wagerService = WagerService();
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWagerStats();
  }

  Future<void> _loadWagerStats() async {
    // Load stats in background
    _wagerService.getWagerStats().then((stats) {
      if (mounted) {
        setState(() {
          // Could store stats for display
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: BRAppBar(
        title: 'My Wagers',
        showBackButton: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Wagers'),
              ),
              const PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'week',
                child: Text('This Week'),
              ),
              const PopupMenuItem(
                value: 'month',
                child: Text('This Month'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          FutureBuilder<WagerStats>(
            future: _wagerService.getWagerStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 140);
              }

              final stats = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(
                          value: stats.pending.toString(),
                          label: 'Active',
                          icon: Icons.timer,
                          color: Colors.white,
                        ),
                        _StatItem(
                          value: stats.wins.toString(),
                          label: 'Won',
                          icon: Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                        _StatItem(
                          value: stats.losses.toString(),
                          label: 'Lost',
                          icon: Icons.cancel,
                          color: Colors.redAccent,
                        ),
                        _StatItem(
                          value: '${stats.winRate.toStringAsFixed(0)}%',
                          label: 'Win Rate',
                          icon: Icons.trending_up,
                          color: Colors.amber,
                        ),
                      ],
                    ),
                    if (stats.totalWagered > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insights, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Total Wagered: ${stats.totalWagered} BR | ROI: ${stats.roi.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Tab Bar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'All'),
              ],
            ),
          ),

          // Wager Lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveWagersList(),
                _buildCompletedWagersList(),
                _buildAllWagersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWagersList() {
    return StreamBuilder<List<Wager>>(
      stream: _wagerService.getActiveWagers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.casino_outlined,
            title: 'No Active Wagers',
            subtitle: 'Place a bet to get started!',
            actionLabel: 'Find Games',
            onAction: () => Navigator.pushNamed(context, '/home'),
          );
        }

        final wagers = _filterWagers(snapshot.data!);
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: wagers.length,
            itemBuilder: (context, index) {
              return _WagerCard(
                wager: wagers[index],
                onCancel: () => _cancelWager(wagers[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompletedWagersList() {
    return FutureBuilder<List<Wager>>(
      future: _wagerService.getWagerHistory(status: 'completed'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No Completed Wagers',
            subtitle: 'Your finished wagers will appear here',
          );
        }

        final wagers = _filterWagers(snapshot.data!);
        
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: wagers.length,
          itemBuilder: (context, index) {
            return _WagerCard(wager: wagers[index]);
          },
        );
      },
    );
  }

  Widget _buildAllWagersList() {
    return FutureBuilder<List<Wager>>(
      future: _wagerService.getWagerHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.receipt_long,
            title: 'No Wagers Yet',
            subtitle: 'Start wagering to see your history',
            actionLabel: 'Browse Games',
            onAction: () => Navigator.pushNamed(context, '/home'),
          );
        }

        final wagers = _filterWagers(snapshot.data!);
        
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: wagers.length,
          itemBuilder: (context, index) {
            return _WagerCard(wager: wagers[index]);
          },
        );
      },
    );
  }

  List<Wager> _filterWagers(List<Wager> wagers) {
    final now = DateTime.now();
    
    switch (_selectedFilter) {
      case 'today':
        return wagers.where((w) => 
          w.placedAt.isAfter(DateTime(now.year, now.month, now.day))
        ).toList();
      case 'week':
        return wagers.where((w) => 
          w.placedAt.isAfter(now.subtract(const Duration(days: 7)))
        ).toList();
      case 'month':
        return wagers.where((w) => 
          w.placedAt.isAfter(DateTime(now.year, now.month, 1))
        ).toList();
      default:
        return wagers;
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelWager(Wager wager) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Wager?'),
        content: Text(
          'Are you sure you want to cancel this ${wager.wagerAmount} BR wager on ${wager.gameTitle}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Wager'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cancel Wager'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _wagerService.cancelWager(wager.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                  ? 'Wager cancelled. ${wager.wagerAmount} BR refunded.'
                  : 'Failed to cancel wager',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _WagerCard extends StatelessWidget {
  final Wager wager;
  final VoidCallback? onCancel;

  const _WagerCard({
    required this.wager,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, h:mm a');
    
    Color statusColor;
    IconData statusIcon;
    
    switch (wager.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.timer;
        break;
      case 'won':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'lost':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      default:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showWagerDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wager.gameTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${wager.poolName} • ${dateFormat.format(wager.placedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wager.isParlay)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PARLAY',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Selections
              ...wager.selections.map((selection) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.sports,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${selection.type}: ${selection.selection}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      selection.odds > 0 ? '+${selection.odds}' : '${selection.odds}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )),

              const Divider(height: 24),

              // Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wager',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        '${wager.wagerAmount} BR',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        wager.status == 'won' ? 'Won' : 'To Win',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        '${wager.potentialPayout} BR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (wager.status == 'pending' && onCancel != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel Wager'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showWagerDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Wager Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _DetailItem('Game', wager.gameTitle),
              _DetailItem('Pool', wager.poolName),
              _DetailItem('Sport', wager.sport.toUpperCase()),
              _DetailItem('Placed', DateFormat('MMM d, yyyy - h:mm a').format(wager.placedAt)),
              _DetailItem('Status', wager.status.toUpperCase()),
              const Divider(height: 32),
              Text(
                'Selections',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ...wager.selections.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(s.description),
                  subtitle: Text('${s.type}: ${s.selection}'),
                  trailing: Text(
                    s.odds > 0 ? '+${s.odds}' : '${s.odds}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wager Amount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${wager.wagerAmount} BR',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Potential Payout',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${wager.potentialPayout} BR',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}