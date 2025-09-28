import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/streaming_service_model.dart';
import '../../theme/app_theme.dart';

class WatchLiveScreen extends StatefulWidget {
  const WatchLiveScreen({Key? key}) : super(key: key);

  @override
  State<WatchLiveScreen> createState() => _WatchLiveScreenState();
}

class _WatchLiveScreenState extends State<WatchLiveScreen> {
  bool _disclaimerAccepted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDisclaimerAcceptance();
  }

  Future<void> _checkDisclaimerAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _disclaimerAccepted = prefs.getBool('watch_disclaimer_accepted') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateDisclaimerAcceptance(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('watch_disclaimer_accepted', value);
    setState(() {
      _disclaimerAccepted = value;
    });
  }

  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);

      // Try different launch modes for better compatibility
      bool launched = false;

      // First try with external application (preferred)
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } catch (e) {
        print('Failed with externalApplication mode: $e');
      }

      // If external application fails, try platform default
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        } catch (e) {
          print('Failed with platformDefault mode: $e');
        }
      }

      // If still not launched, try in-app web view as last resort
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        } catch (e) {
          print('Failed with inAppWebView mode: $e');
        }
      }

      // If all methods fail, show error
      if (!launched && mounted) {
        // Try copying to clipboard as fallback
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open browser. URL copied to clipboard: $url'),
            backgroundColor: AppTheme.warningAmber,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('Error launching URL $url: $e');
      if (mounted) {
        // Copy to clipboard as fallback
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link. URL copied to clipboard.'),
            backgroundColor: AppTheme.errorPink,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBlue,
        title: const Text(
          'Watch Live Sports',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade700,
                    Colors.red.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'IMPORTANT NOTICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• These are third-party streaming links not affiliated with Bragging Rights\n'
                    '• We do not host, promote, or endorse any content on these sites\n'
                    '• Users must verify the legality of streaming services in their jurisdiction\n'
                    '• Some content may be geo-restricted or require VPN access\n'
                    '• Use at your own risk and discretion',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Legal Disclaimer
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryCyan.withOpacity(0.3),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LEGAL DISCLAIMER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bragging Rights provides these links for informational purposes only. '
                    'We make no representations about the content, legality, or safety of '
                    'these external sites. Users are responsible for complying with all '
                    'applicable laws in their region. We strongly recommend using official, '
                    'licensed streaming services where available.',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Official Streaming Services
            const Text(
              'OFFICIAL STREAMING SERVICES',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'We recommend using these legal streaming options:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Official Services Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: StreamingServiceData.officialServices.length,
              itemBuilder: (context, index) {
                final service = StreamingServiceData.officialServices[index];
                return _buildOfficialServiceCard(service);
              },
            ),

            const SizedBox(height: 30),

            // Acceptance Checkbox
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Checkbox(
                    value: _disclaimerAccepted,
                    onChanged: (value) {
                      if (value != null) {
                        _updateDisclaimerAcceptance(value);
                      }
                    },
                    activeColor: AppTheme.primaryCyan,
                  ),
                  const Expanded(
                    child: Text(
                      'I understand and accept the terms and conditions',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Third-Party Links Section (Conditional)
            if (_disclaimerAccepted) ...[
              const SizedBox(height: 30),
              const Text(
                'THIRD-PARTY STREAMING LINKS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),

              // Safety Tips
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAFETY TIPS:',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Use an ad-blocker for safety\n'
                      '• Beware of pop-ups and redirects\n'
                      '• Never enter personal information\n'
                      '• Consider using a VPN\n'
                      '• Keep your device security updated',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Third-Party Services List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: StreamingServiceData.thirdPartyServices.length,
                itemBuilder: (context, index) {
                  final service = StreamingServiceData.thirdPartyServices[index];
                  return _buildThirdPartyServiceCard(service);
                },
              ),
            ],

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialServiceCard(StreamingService service) {
    return InkWell(
      onTap: () => _launchURL(service.url),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryCyan.withOpacity(0.1),
              AppTheme.neonGreen.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.neonGreen.withOpacity(0.3),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: AppTheme.primaryCyan,
                ),
              ],
            ),
            if (service.description != null) ...[
              const SizedBox(height: 4),
              Text(
                service.description!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (service.cost != null) ...[
              const SizedBox(height: 4),
              Text(
                service.cost!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.neonGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThirdPartyServiceCard(StreamingService service) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _launchURL(service.url),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.warning_outlined,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.mirrorNumber != null
                          ? '${service.name} - Mirror ${service.mirrorNumber}'
                          : service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (service.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      service.url,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new,
                color: AppTheme.primaryCyan,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}