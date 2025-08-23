import 'package:flutter/material.dart';
import '../services/pool_service.dart';

class PoolCreationLimitIndicator extends StatefulWidget {
  final VoidCallback? onCreatePressed;
  
  const PoolCreationLimitIndicator({
    super.key,
    this.onCreatePressed,
  });

  @override
  State<PoolCreationLimitIndicator> createState() => _PoolCreationLimitIndicatorState();
}

class _PoolCreationLimitIndicatorState extends State<PoolCreationLimitIndicator> {
  final PoolService _poolService = PoolService();
  int _currentPoolCount = 0;
  bool _isLoading = true;
  static const int _maxPools = 5;
  
  @override
  void initState() {
    super.initState();
    _loadPoolCount();
  }
  
  Future<void> _loadPoolCount() async {
    final count = await _poolService.getUserCreatedPoolCount();
    if (mounted) {
      setState(() {
        _currentPoolCount = count;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    final canCreateMore = _currentPoolCount < _maxPools;
    final remainingSlots = _maxPools - _currentPoolCount;
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canCreateMore ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canCreateMore ? Colors.blue.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canCreateMore ? Icons.check_circle : Icons.warning,
                color: canCreateMore ? Colors.blue : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canCreateMore 
                        ? 'You can create $remainingSlots more pool${remainingSlots != 1 ? 's' : ''}'
                        : 'Pool creation limit reached',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: canCreateMore ? Colors.blue : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Active pools: $_currentPoolCount/$_maxPools',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Visual indicator bars
          Row(
            children: List.generate(_maxPools, (index) {
              final isActive = index < _currentPoolCount;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive 
                      ? (canCreateMore ? Colors.blue : Colors.orange)
                      : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          if (!canCreateMore) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delete or wait for existing pools to complete before creating new ones',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.onCreatePressed != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canCreateMore ? widget.onCreatePressed : null,
                icon: const Icon(Icons.add_circle),
                label: Text(canCreateMore ? 'Create New Pool' : 'Limit Reached'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCreateMore ? Colors.blue : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}