import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/pool_model.dart';
import '../../services/pool_service.dart';
import '../../widgets/pool_creation_limit_indicator.dart';
import '../../theme/app_theme.dart';

class MyPoolsScreen extends StatefulWidget {
  const MyPoolsScreen({super.key});

  @override
  State<MyPoolsScreen> createState() => _MyPoolsScreenState();
}

class _MyPoolsScreenState extends State<MyPoolsScreen> {
  final PoolService _poolService = PoolService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Pools'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Text('Please log in to view your pools'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pools'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Pool creation limit indicator
          PoolCreationLimitIndicator(
            onCreatePressed: () {
              Navigator.pushNamed(context, '/create-pool');
            },
          ),
          
          // Tabs for created vs joined pools
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Created by Me'),
                      Tab(text: 'Joined Pools'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCreatedPoolsList(userId),
                        _buildJoinedPoolsList(userId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreatedPoolsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('pools')
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pool, size: 64, color: AppTheme.surfaceBlue),
                const SizedBox(height: 16),
                const Text(
                  'No pools created yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a private pool to play with friends',
                  style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create-pool');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Pool'),
                ),
              ],
            ),
          );
        }
        
        final pools = snapshot.data!.docs
            .map((doc) => Pool.fromFirestore(doc))
            .toList();
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pools.length,
          itemBuilder: (context, index) {
            final pool = pools[index];
            return _buildCreatedPoolCard(pool);
          },
        );
      },
    );
  }
  
  Widget _buildCreatedPoolCard(Pool pool) {
    final spotsLeft = pool.maxPlayers - pool.currentPlayers;
    final fillPercentage = pool.currentPlayers / pool.maxPlayers;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pool.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${pool.code ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.surfaceBlue.withOpacity(0.6),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${pool.buyIn} BR',
                    style: const TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: AppTheme.surfaceBlue.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  '${pool.currentPlayers}/${pool.maxPlayers} players',
                  style: TextStyle(fontSize: 14, color: AppTheme.surfaceBlue.withOpacity(0.6)),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer, size: 16, color: AppTheme.surfaceBlue.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  'Closes in ${_formatTimeRemaining(pool.closeTime)}',
                  style: TextStyle(fontSize: 14, color: AppTheme.surfaceBlue.withOpacity(0.6)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fillPercentage,
              backgroundColor: AppTheme.surfaceBlue,
              valueColor: AlwaysStoppedAnimation(
                fillPercentage == 1.0 ? AppTheme.errorPink : AppTheme.primaryCyan,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spotsLeft > 0 
                ? '$spotsLeft spots remaining' 
                : 'Pool is full',
              style: TextStyle(
                fontSize: 12,
                color: spotsLeft > 0 ? AppTheme.surfaceBlue.withOpacity(0.6) : AppTheme.errorPink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _sharePoolCode(pool);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pool.currentPlayers > 1 
                      ? null 
                      : () => _deletePool(pool),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorPink,
                    ),
                  ),
                ),
              ],
            ),
            if (pool.currentPlayers > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Cannot delete - other players have joined',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.warningAmber,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildJoinedPoolsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('user_pools')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_basketball, size: 64, color: AppTheme.surfaceBlue),
                const SizedBox(height: 16),
                const Text(
                  'No pools joined yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join pools to start playing',
                  style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/pools');
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Browse Pools'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildJoinedPoolCard(data);
          },
        );
      },
    );
  }
  
  Widget _buildJoinedPoolCard(Map<String, dynamic> poolData) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryCyan.withOpacity(0.1),
          child: Text(
            '${poolData['buyIn']}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(poolData['poolName'] ?? 'Pool'),
        subtitle: Text('Joined ${_formatDate(poolData['joinedAt'])}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.neonGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            poolData['poolType'] ?? 'active',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.neonGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatTimeRemaining(DateTime closeTime) {
    final remaining = closeTime.difference(DateTime.now());
    if (remaining.isNegative) return 'Closed';
    
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m';
    } else {
      return '${remaining.inSeconds}s';
    }
  }
  
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return 'Recently';
    }
    
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  void _sharePoolCode(Pool pool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Pool'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.share, size: 48, color: AppTheme.primaryCyan),
            const SizedBox(height: 16),
            Text(
              'Pool Code: ${pool.code ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with friends to join',
              style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement actual sharing
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Code'),
          ),
        ],
      ),
    );
  }
  
  void _deletePool(Pool pool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pool?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, size: 48, color: AppTheme.warningAmber),
            const SizedBox(height: 16),
            Text('Are you sure you want to delete "${pool.name}"?'),
            const SizedBox(height: 8),
            Text(
              'Your ${pool.buyIn} BR buy-in will be refunded.',
              style: TextStyle(color: AppTheme.surfaceBlue.withOpacity(0.6), fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await _poolService.deletePool(pool.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Pool deleted and ${pool.buyIn} BR refunded'
                        : 'Failed to delete pool',
                    ),
                    backgroundColor: success ? AppTheme.neonGreen : AppTheme.errorPink,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorPink),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}