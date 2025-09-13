import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:contacts_service/contacts_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../theme/app_theme.dart';

// Temporary Contact class until contacts_service package is fixed
class Contact {
  String? displayName;
  List<Item>? phones;
  Contact({this.displayName, this.phones});
}

class Item {
  String? value;
  Item({this.value});
}

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({Key? key}) : super(key: key);

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  Map<String, String> _registeredUsers = {};
  Map<String, bool> _pendingInvites = {};
  Map<String, bool> _existingFriends = {};
  bool _isLoading = true;
  bool _hasContactPermission = false;
  String? _currentUserId;
  String? _currentUserInviteCode;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _generateInviteCode();
    await _checkContactPermission();
    if (_hasContactPermission) {
      await _loadContacts();
      await _checkRegisteredUsers();
      await _loadExistingFriends();
      await _loadPendingInvites();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _generateInviteCode() async {
    if (_currentUserId != null) {
      _currentUserInviteCode = _currentUserId!.substring(0, 8).toUpperCase();
    }
  }

  Future<void> _checkContactPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      setState(() => _hasContactPermission = true);
    }
  }

  Future<void> _requestContactPermission() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      setState(() => _hasContactPermission = true);
      await _loadContacts();
      await _checkRegisteredUsers();
      await _loadExistingFriends();
      await _loadPendingInvites();
    } else if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Permission Required'),
        content: const Text(
          'To find and invite friends, we need access to your contacts. '
          'Please enable contact permissions in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadContacts() async {
    try {
      // Temporarily disabled until contacts_service is fixed
      // final contacts = await ContactsService.getContacts();
      // setState(() {
      //   _contacts = contacts.toList();
      //   _filteredContacts = _contacts;
      // });
      
      // For now, use empty list
      setState(() {
        _contacts = [];
        _filteredContacts = [];
      });
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  String _hashPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final bytes = utf8.encode(cleanNumber);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _checkRegisteredUsers() async {
    if (_contacts.isEmpty) return;

    final phoneHashes = <String>[];
    for (final contact in _contacts) {
      for (final phone in contact.phones ?? []) {
        if (phone.value != null) {
          phoneHashes.add(_hashPhoneNumber(phone.value!));
        }
      }
    }

    if (phoneHashes.isEmpty) return;

    try {
      final chunks = <List<String>>[];
      for (var i = 0; i < phoneHashes.length; i += 10) {
        chunks.add(phoneHashes.sublist(
          i,
          i + 10 > phoneHashes.length ? phoneHashes.length : i + 10,
        ));
      }

      final registeredUsers = <String, String>{};
      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection('users')
            .where('phoneHash', whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final phoneHash = doc.data()['phoneHash'] as String?;
          if (phoneHash != null) {
            registeredUsers[phoneHash] = doc.id;
          }
        }
      }

      setState(() {
        _registeredUsers = registeredUsers;
      });
    } catch (e) {
      print('Error checking registered users: $e');
    }
  }

  Future<void> _loadExistingFriends() async {
    if (_currentUserId == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();

      final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
      final friendsMap = <String, bool>{};
      
      for (final friendId in friends) {
        final friendDoc = await _firestore
            .collection('users')
            .doc(friendId)
            .get();
        final phoneHash = friendDoc.data()?['phoneHash'];
        if (phoneHash != null) {
          friendsMap[phoneHash] = true;
        }
      }

      setState(() {
        _existingFriends = friendsMap;
      });
    } catch (e) {
      print('Error loading existing friends: $e');
    }
  }

  Future<void> _loadPendingInvites() async {
    if (_currentUserId == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();

      final pendingInvites = List<String>.from(
        userDoc.data()?['pendingInvites'] ?? [],
      );

      final invitesMap = <String, bool>{};
      for (final phoneNumber in pendingInvites) {
        invitesMap[_hashPhoneNumber(phoneNumber)] = true;
      }

      setState(() {
        _pendingInvites = invitesMap;
      });
    } catch (e) {
      print('Error loading pending invites: $e');
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  ContactStatus _getContactStatus(Contact contact) {
    final phoneNumber = contact.phones?.firstOrNull?.value;
    if (phoneNumber == null) return ContactStatus.noPhone;

    final phoneHash = _hashPhoneNumber(phoneNumber);
    
    if (_existingFriends[phoneHash] == true) {
      return ContactStatus.alreadyFriend;
    }
    
    if (_registeredUsers.containsKey(phoneHash)) {
      return ContactStatus.onApp;
    }
    
    if (_pendingInvites[phoneHash] == true) {
      return ContactStatus.invited;
    }
    
    return ContactStatus.notOnApp;
  }

  Future<void> _sendFriendRequest(Contact contact) async {
    if (_currentUserId == null) return;

    final phoneNumber = contact.phones?.firstOrNull?.value;
    if (phoneNumber == null) return;

    final phoneHash = _hashPhoneNumber(phoneNumber);
    final friendId = _registeredUsers[phoneHash];
    if (friendId == null) return;

    try {
      await _firestore.collection('users').doc(friendId).update({
        'friendRequests': FieldValue.arrayUnion([_currentUserId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${contact.displayName}'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send friend request'),
          backgroundColor: AppTheme.errorPink,
        ),
      );
    }
  }

  Future<void> _sendSMSInvite(Contact contact) async {
    if (_currentUserInviteCode == null) return;

    final phoneNumber = contact.phones?.firstOrNull?.value;
    if (phoneNumber == null) return;

    final message = Uri.encodeComponent(
      'Join me on Bragging Rights! 🏆\n\n'
      'Download the app and use my code: $_currentUserInviteCode\n\n'
      'App Store: [app_store_link]\n'
      'Google Play: [google_play_link]'
    );

    final uri = Uri.parse('sms:$phoneNumber?body=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        await _firestore.collection('users').doc(_currentUserId).update({
          'pendingInvites': FieldValue.arrayUnion([phoneNumber]),
        });

        setState(() {
          _pendingInvites[_hashPhoneNumber(phoneNumber)] = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open SMS app'),
          backgroundColor: AppTheme.errorPink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Invite Friends'),
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.shareNetwork),
            onPressed: _shareInviteCode,
          ),
        ],
      ),
      body: _hasContactPermission
          ? _buildContactsList()
          : _buildPermissionRequest(),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.addressBook,
              size: 80,
              color: AppTheme.surfaceBlue.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            const Text(
              'Find Friends on Bragging Rights',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Allow access to your contacts to easily find and invite friends to compete with you.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.surfaceBlue.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestContactPermission,
              icon: Icon(PhosphorIconsRegular.userPlus),
              label: const Text('Allow Contact Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip for Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E1E1E),
          child: TextField(
            controller: _searchController,
            onChanged: _filterContacts,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredContacts.length,
            itemBuilder: (context, index) {
              final contact = _filteredContacts[index];
              return _buildContactTile(contact);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile(Contact contact) {
    final status = _getContactStatus(contact);
    final displayName = contact.displayName ?? 'Unknown';
    final phoneNumber = contact.phones?.firstOrNull?.value ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(status).withOpacity(0.2),
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(color: _getStatusColor(status)),
        ),
      ),
      title: Text(displayName),
      subtitle: Text(
        _getStatusText(status),
        style: TextStyle(color: _getStatusColor(status)),
      ),
      trailing: _buildActionButton(contact, status),
    );
  }

  Widget _buildActionButton(Contact contact, ContactStatus status) {
    switch (status) {
      case ContactStatus.alreadyFriend:
        return Icon(
          PhosphorIconsRegular.checkCircle,
          color: AppTheme.neonGreen,
        );
      case ContactStatus.onApp:
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(contact),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryCyan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Add'),
        );
      case ContactStatus.invited:
        return TextButton(
          onPressed: () => _sendSMSInvite(contact),
          child: const Text('Remind'),
        );
      case ContactStatus.notOnApp:
        return ElevatedButton(
          onPressed: () => _sendSMSInvite(contact),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Invite'),
        );
      case ContactStatus.noPhone:
        return Icon(
          PhosphorIconsRegular.warning,
          color: AppTheme.surfaceBlue,
        );
    }
  }

  Color _getStatusColor(ContactStatus status) {
    switch (status) {
      case ContactStatus.alreadyFriend:
        return AppTheme.neonGreen;
      case ContactStatus.onApp:
        return AppTheme.primaryCyan;
      case ContactStatus.invited:
        return AppTheme.warningAmber;
      case ContactStatus.notOnApp:
        return Colors.purple;
      case ContactStatus.noPhone:
        return AppTheme.surfaceBlue;
    }
  }

  String _getStatusText(ContactStatus status) {
    switch (status) {
      case ContactStatus.alreadyFriend:
        return 'Already friends';
      case ContactStatus.onApp:
        return 'On Bragging Rights';
      case ContactStatus.invited:
        return 'Invite sent';
      case ContactStatus.notOnApp:
        return 'Not on app yet';
      case ContactStatus.noPhone:
        return 'No phone number';
    }
  }

  void _shareInviteCode() {
    if (_currentUserInviteCode == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryCyan),
              ),
              child: Text(
                _currentUserInviteCode!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this code with friends to connect on Bragging Rights!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

enum ContactStatus {
  alreadyFriend,
  onApp,
  invited,
  notOnApp,
  noPhone,
}