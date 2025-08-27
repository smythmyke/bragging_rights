import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../services/transaction_service.dart';
import '../../widgets/br_app_bar.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  late TabController _tabController;
  TransactionType? _selectedType;
  DateTimeRange? _dateRange;
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  List<Transaction> _transactions = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    setState(() => _isLoadingMore = true);

    final page = await _transactionService.getTransactionPage(
      pageSize: 20,
      lastDocument: _lastDocument,
      type: _selectedType,
    );

    setState(() {
      _transactions.addAll(page.transactions);
      _lastDocument = page.lastDocument;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Future<void> _exportTransactions() async {
    try {
      final csv = await _transactionService.exportTransactions(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        type: _selectedType,
      );

      // In a real app, you'd save this to a file or share it
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transactions exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: BRAppBar(
        title: 'Transaction History',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportTransactions,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          FutureBuilder<TransactionSummary>(
            future: _transactionService.getTransactionSummary(
              startDate: _dateRange?.start,
              endDate: _dateRange?.end,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 120);
              }

              final summary = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Wagered',
                          value: '${summary.totalWagers} BR',
                          icon: Icons.casino,
                          color: Colors.white,
                        ),
                        _SummaryItem(
                          label: 'Won',
                          value: '${summary.totalWinnings} BR',
                          icon: Icons.emoji_events,
                          color: Colors.amber,
                        ),
                        _SummaryItem(
                          label: 'Net',
                          value: '${summary.netChange >= 0 ? '+' : ''}${summary.netChange} BR',
                          icon: summary.netChange >= 0 
                              ? Icons.trending_up 
                              : Icons.trending_down,
                          color: summary.netChange >= 0 
                              ? Colors.greenAccent 
                              : Colors.redAccent,
                        ),
                      ],
                    ),
                    if (summary.roi != 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ROI: ${summary.roi.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Filter Tabs
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Wagers'),
                Tab(text: 'Winnings'),
              ],
              onTap: (index) {
                setState(() {
                  switch (index) {
                    case 0:
                      _selectedType = null;
                      break;
                    case 1:
                      _selectedType = TransactionType.wager;
                      break;
                    case 2:
                      _selectedType = TransactionType.winnings;
                      break;
                  }
                  _transactions.clear();
                  _lastDocument = null;
                  _hasMore = true;
                });
              },
            ),
          ),

          // Transaction List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(),
                _buildTransactionList(),
                _buildTransactionList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<List<Transaction>>(
      stream: _transactionService.getTransactionHistory(
        limit: 50,
        type: _selectedType,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _transactions.clear();
              _lastDocument = null;
              _hasMore = true;
            });
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: transactions.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == transactions.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final transaction = transactions[index];
              return _TransactionTile(transaction: transaction);
            },
          ),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = transaction.amount >= 0;
    final dateFormat = DateFormat('MMM d, h:mm a');

    IconData icon;
    Color iconColor;

    switch (transaction.type) {
      case TransactionType.wager:
        icon = Icons.casino;
        iconColor = Colors.orange;
        break;
      case TransactionType.winnings:
        icon = Icons.emoji_events;
        iconColor = Colors.amber;
        break;
      case TransactionType.refund:
        icon = Icons.replay;
        iconColor = Colors.blue;
        break;
      case TransactionType.weekly_allowance:
        icon = Icons.calendar_today;
        iconColor = Colors.green;
        break;
      case TransactionType.signup_bonus:
        icon = Icons.card_giftcard;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.attach_money;
        iconColor = theme.colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          transaction.description,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          dateFormat.format(transaction.timestamp),
          style: theme.textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.formattedAmount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
            if (transaction.balanceAfter != null)
              Text(
                'Balance: ${transaction.balanceAfter} BR',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
          ],
        ),
        onTap: () {
          _showTransactionDetails(context, transaction);
        },
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _DetailRow('Type', transaction.typeDisplay),
              _DetailRow('Amount', transaction.formattedAmount),
              _DetailRow('Description', transaction.description),
              _DetailRow(
                'Date',
                DateFormat('MMMM d, yyyy - h:mm a').format(transaction.timestamp),
              ),
              if (transaction.balanceBefore != null)
                _DetailRow('Balance Before', '${transaction.balanceBefore} BR'),
              if (transaction.balanceAfter != null)
                _DetailRow('Balance After', '${transaction.balanceAfter} BR'),
              if (transaction.metadata != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Additional Info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...transaction.metadata!.entries
                    .map((e) => _DetailRow(e.key, e.value.toString())),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}