import 'package:flutter/material.dart';
import 'dart:async';

class InfoEdgeCarousel extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onEdgePressed;
  final Duration autoScrollDelay;
  final Duration animationDuration;

  const InfoEdgeCarousel({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onEdgePressed,
    this.autoScrollDelay = const Duration(seconds: 5),
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<InfoEdgeCarousel> createState() => _InfoEdgeCarouselState();
}

class _InfoEdgeCarouselState extends State<InfoEdgeCarousel> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  bool _userHasInteracted = false;
  bool _hasAutoScrolled = false;

  @override
  void initState() {
    super.initState();
    // print('[InfoEdgeCarousel] initState called for ${widget.title}');
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    
    // Setup pulse animation for Edge button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start auto-scroll timer
    _startAutoScrollTimer();
  }

  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    // print('[InfoEdgeCarousel] Starting auto-scroll timer for ${widget.title}');
    // print('[InfoEdgeCarousel] User has interacted: $_userHasInteracted, Has auto-scrolled: $_hasAutoScrolled');
    
    if (!_userHasInteracted && !_hasAutoScrolled) {
      _autoScrollTimer = Timer(widget.autoScrollDelay, () {
        // print('[InfoEdgeCarousel] Timer fired for ${widget.title}');
        // print('[InfoEdgeCarousel] Mounted: $mounted, Current page: $_currentPage, User interacted: $_userHasInteracted');
        
        if (mounted && !_userHasInteracted && _currentPage == 0 && !_hasAutoScrolled) {
          // print('[InfoEdgeCarousel] Executing auto-scroll to page 1');
          _hasAutoScrolled = true;
          _pageController.animateToPage(
            1,
            duration: widget.animationDuration,
            curve: Curves.easeInOut,
          ).then((_) {
            // print('[InfoEdgeCarousel] Auto-scroll animation completed');
            if (mounted) {
              setState(() {
                _currentPage = 1;
              });
            }
          });
        } else {
          // print('[InfoEdgeCarousel] Auto-scroll cancelled - conditions not met');
        }
      });
    } else {
      // print('[InfoEdgeCarousel] Auto-scroll not started - user already interacted or already scrolled');
    }
  }

  @override
  void dispose() {
    // print('[InfoEdgeCarousel] Disposing ${widget.title}');
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // print('[InfoEdgeCarousel] Building ${widget.title}, current page: $_currentPage');
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Prevent scroll notifications from bubbling up to parent
              if (notification is UserScrollNotification) {
                // print('[InfoEdgeCarousel] User scrolling detected');
                _userHasInteracted = true;
                _autoScrollTimer?.cancel();
              }
              return true; // Stop the notification from bubbling up
            },
            child: PageView(
              controller: _pageController,
              pageSnapping: true,
              physics: const PageScrollPhysics(),
              onPageChanged: (page) {
                // print('[InfoEdgeCarousel] Page changed to: $page');
                setState(() {
                  _currentPage = page;
                  if (page != 0) {
                    _userHasInteracted = true;
                  }
                });
                _autoScrollTimer?.cancel();
              },
              children: [
                _buildInfoCard(),
                _buildEdgeCard(),
              ],
            ),
          ),
          // Page indicators
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageIndicator(0),
                const SizedBox(width: 8),
                _buildPageIndicator(1),
              ],
            ),
          ),
          // Hint arrow for swiping
          if (_currentPage == 0 && !_userHasInteracted)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(widget.icon, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.amber, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: widget.onEdgePressed,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get The Edge',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Unlock insider intelligence',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageIndicator(int page) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _currentPage == page ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == page 
            ? (page == 1 ? Colors.amber : Colors.blue)
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}