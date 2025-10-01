import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/wallet_service.dart';
import '../../services/victory_coin_service.dart';
import '../../services/escrow_service.dart';

class WagerSelectionSheet extends StatefulWidget {
  final VoidCallback? onSkip;

  const WagerSelectionSheet({
    super.key,
    this.onSkip,
  });

  @override
  State<WagerSelectionSheet> createState() => _WagerSelectionSheetState();
}

class _WagerSelectionSheetState extends State<WagerSelectionSheet> {
  final WalletService _walletService = WalletService();
  final VictoryCoinService _vcService = VictoryCoinService();
  final EscrowService _escrowService = EscrowService(
    FirebaseFirestore.instance,
  );

  String _selectedCurrency = 'BR'; // 'BR' or 'VC'
  double _wagerAmount = 50;

  int _brBalance = 0;
  int _vcBalance = 0;
  int _brLocked = 0;
  int _vcLocked = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      setState(() => _isLoading = true);

      // Get BR balance (uses current user from FirebaseAuth)
      final brBalance = await _walletService.getCurrentBalance();

      // Get VC balance
      final vcModel = await _vcService.getUserVC(userId);
      final vcBalance = vcModel?.balance ?? 0;

      // Get locked funds
      final lockedFunds = await _escrowService.getUserLockedFunds(userId);

      setState(() {
        _brBalance = brBalance;
        _vcBalance = vcBalance;
        _brLocked = lockedFunds['BR'] ?? 0;
        _vcLocked = lockedFunds['VC'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading balances: $e');
      setState(() => _isLoading = false);
    }
  }

  int get _maxWager {
    if (_selectedCurrency == 'BR') {
      final available = _brBalance - _brLocked;
      return available.clamp(10, 5000);
    } else {
      final available = _vcBalance - _vcLocked;
      return available.clamp(1, 100);
    }
  }

  int get _minWager {
    return _selectedCurrency == 'BR' ? 10 : 1;
  }

  int get _availableBalance {
    if (_selectedCurrency == 'BR') {
      return _brBalance - _brLocked;
    } else {
      return _vcBalance - _vcLocked;
    }
  }

  bool get _canWager {
    return _availableBalance >= _wagerAmount.toInt();
  }

  String get _currencySymbol {
    return _selectedCurrency == 'BR' ? 'BR' : 'VC';
  }

  Color get _currencyColor {
    return _selectedCurrency == 'BR'
        ? Colors.amber
        : Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: _currencyColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Wager',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onSkip != null)
                  TextButton(
                    onPressed: () {
                      widget.onSkip?.call();
                      Navigator.pop(context, null);
                    },
                    child: const Text('Skip'),
                  ),
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Currency Toggle
                  _buildCurrencyToggle(),
                  const SizedBox(height: 24),

                  // Balance Display
                  _buildBalanceDisplay(),
                  const SizedBox(height: 24),

                  // Wager Amount Display
                  _buildWagerDisplay(),
                  const SizedBox(height: 16),

                  // Slider
                  _buildSlider(),
                  const SizedBox(height: 24),

                  // Quick Select Buttons
                  _buildQuickSelectButtons(),
                  const SizedBox(height: 24),

                  // Confirm Button
                  _buildConfirmButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrencyToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCurrencyOption('BR', 'BR Coins', Colors.amber),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[800],
          ),
          Expanded(
            child: _buildCurrencyOption('VC', 'Victory Coins', Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyOption(String currency, String label, Color color) {
    final isSelected = _selectedCurrency == currency;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCurrency = currency;
          _wagerAmount = _minWager.toDouble();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              currency == 'BR' ? Icons.monetization_on : Icons.stars,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _currencyColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$_availableBalance',
                    style: TextStyle(
                      color: _currencyColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currencySymbol,
                    style: TextStyle(
                      color: _currencyColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_brLocked > 0 || _vcLocked > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Locked in Escrow',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${_selectedCurrency == 'BR' ? _brLocked : _vcLocked} $_currencySymbol',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWagerDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _currencyColor.withOpacity(0.2),
            _currencyColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _currencyColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Wager Amount',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_wagerAmount.toInt()}',
                style: TextStyle(
                  color: _currencyColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _currencySymbol,
                  style: TextStyle(
                    color: _currencyColor.withOpacity(0.7),
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _currencyColor,
            inactiveTrackColor: _currencyColor.withOpacity(0.2),
            thumbColor: _currencyColor,
            overlayColor: _currencyColor.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: _wagerAmount.clamp(_minWager.toDouble(), _maxWager.toDouble()),
            min: _minWager.toDouble(),
            max: _maxWager.toDouble(),
            divisions: _selectedCurrency == 'BR' ? 99 : 99,
            onChanged: (value) {
              setState(() {
                _wagerAmount = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_minWager $_currencySymbol',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                '$_maxWager $_currencySymbol',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSelectButtons() {
    final List<int> quickAmounts = _selectedCurrency == 'BR'
        ? [50, 100, 250, 500, 1000]
        : [5, 10, 25, 50, 100];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: quickAmounts.map((amount) {
        final isAvailable = amount <= _availableBalance;
        final isSelected = _wagerAmount.toInt() == amount;

        return InkWell(
          onTap: isAvailable
              ? () {
                  setState(() {
                    _wagerAmount = amount.toDouble();
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? _currencyColor.withOpacity(0.3)
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? _currencyColor
                    : isAvailable
                        ? Colors.grey[700]!
                        : Colors.grey[900]!,
              ),
            ),
            child: Text(
              '$amount',
              style: TextStyle(
                color: isAvailable
                    ? (isSelected ? _currencyColor : Colors.white)
                    : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmButton() {
    return ElevatedButton(
      onPressed: _canWager
          ? () {
              Navigator.pop(context, {
                'amount': _wagerAmount.toInt(),
                'currency': _selectedCurrency,
              });
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _canWager ? _currencyColor : Colors.grey[800],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: Colors.grey[800],
        disabledForegroundColor: Colors.grey[600],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _canWager ? Icons.check_circle : Icons.error_outline,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _canWager
                ? 'Confirm Wager'
                : 'Insufficient Balance',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}