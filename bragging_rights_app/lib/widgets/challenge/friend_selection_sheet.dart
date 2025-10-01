import 'package:flutter/material.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';

class FriendSelectionSheet extends StatefulWidget {
  final String sportType;
  final String eventId;
  final String eventName;
  final Map<String, dynamic>? wagerInfo; // {amount: int, currency: string}

  const FriendSelectionSheet({
    Key? key,
    required this.sportType,
    required this.eventId,
    required this.eventName,
    this.wagerInfo,
  }) : super(key: key);

  @override
  State<FriendSelectionSheet> createState() => _FriendSelectionSheetState();
}

class _FriendSelectionSheetState extends State<FriendSelectionSheet> {
  final FriendService _friendService = FriendService();
  final Set<String> _selectedFriends = {};
  List<FriendData> _friends = [];
  List<FriendData> _filteredFriends = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeTab = 'friends';

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);

    _friendService.getFriendsStream().listen((friends) {
      setState(() {
        _friends = friends;
        _filteredFriends = friends;
        _isLoading = false;
      });
    });
  }

  void _filterFriends(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((friend) {
          return friend.displayName.toLowerCase().contains(query.toLowerCase()) ||
              friend.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_selectedFriends.contains(friendId)) {
        _selectedFriends.remove(friendId);
      } else {
        _selectedFriends.add(friendId);
      }
    });
  }

  void _sendChallenges() {
    if (_selectedFriends.isEmpty) return;
    Navigator.pop(context, {
      'type': 'friend',
      'friendIds': _selectedFriends.toList(),
    });
  }

  void _createOpenChallenge() {
    Navigator.pop(context, {
      'type': 'open',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.cardBlue,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderCyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Challenge Friends',
                    style: AppTheme.neonText(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Event info and wager display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getSportIcon(widget.sportType),
                      color: AppTheme.primaryCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.eventName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (widget.wagerInfo != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getWagerColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getWagerColor().withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.wagerInfo!['currency'] == 'BR'
                              ? Icons.monetization_on
                              : Icons.stars,
                          color: _getWagerColor(),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Wager: ${widget.wagerInfo!['amount']} ${widget.wagerInfo!['currency']}',
                          style: TextStyle(
                            color: _getWagerColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Friends must match this wager to accept',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryCyan),
                filled: true,
                fillColor: AppTheme.surfaceBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.borderCyan.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.borderCyan.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryCyan,
                  ),
                ),
              ),
              onChanged: _filterFriends,
            ),
          ),

          // Friends list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryCyan,
                    ),
                  )
                : _filteredFriends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No friends yet'
                                  : 'No friends found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 16,
                              ),
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Invite friends to start challenging!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          final isSelected = _selectedFriends.contains(friend.id);

                          return _FriendTile(
                            friend: friend,
                            isSelected: isSelected,
                            onTap: () => _toggleFriend(friend.id),
                          );
                        },
                      ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.borderCyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createOpenChallenge,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Open Challenge'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryCyan,
                      side: const BorderSide(color: AppTheme.primaryCyan),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedFriends.isNotEmpty ? _sendChallenges : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text('Send (${_selectedFriends.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      foregroundColor: AppTheme.deepBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.white24,
                      disabledForegroundColor: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'mma':
      case 'boxing':
        return Icons.sports_mma;
      case 'nfl':
        return Icons.sports_football;
      case 'nba':
        return Icons.sports_basketball;
      case 'nhl':
        return Icons.sports_hockey;
      case 'mlb':
        return Icons.sports_baseball;
      case 'soccer':
        return Icons.sports_soccer;
      default:
        return Icons.sports;
    }
  }

  Color _getWagerColor() {
    if (widget.wagerInfo == null) return Colors.grey;
    return widget.wagerInfo!['currency'] == 'BR' ? Colors.amber : Colors.purple;
  }
}

class _FriendTile extends StatelessWidget {
  final FriendData friend;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendTile({
    Key? key,
    required this.friend,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(friend.lastActive);
    final isOnline = difference.inMinutes < 5;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryCyan.withOpacity(0.1)
            : AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryCyan
              : AppTheme.borderCyan.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryCyan.withOpacity(0.2),
              child: Text(
                friend.displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.surfaceBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friend.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              'Win Rate: ${friend.winRate.toStringAsFixed(1)}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            if (friend.currentStreak > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔥 ${friend.currentStreak}',
                  style: const TextStyle(
                    color: AppTheme.warningAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (_) => onTap(),
          activeColor: AppTheme.primaryCyan,
          checkColor: AppTheme.deepBlue,
        ),
      ),
    );
  }
}