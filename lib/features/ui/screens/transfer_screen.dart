import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transfer_provider.dart';

class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'File Transfer',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_add_outlined, color: Colors.black87),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.black87),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Bar
          if (transferState.isServerRunning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_tethering,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sharing at http://${transferState.localIp}:8080',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(transferProvider.notifier).stopAll(),
                    child: const Text('STOP'),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Send and Receive Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          label: 'SEND',
                          icon: Icons.upload_rounded,
                          active:
                              transferState.status ==
                              TransferStatus.transferring,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2EE48E), Color(0xFF27C07E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => _handleSend(context, ref),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          label: 'RECEIVE',
                          icon: Icons.download_rounded,
                          active:
                              transferState.status == TransferStatus.connected,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5D69F6), Color(0xFF4A54E1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => ref
                              .read(transferProvider.notifier)
                              .startReceive(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Dynamic Content based on State
                  if (transferState.status == TransferStatus.searching)
                    _buildStatusCard(
                      icon: Icons.radar,
                      title: 'Searching for devices...',
                      subtitle:
                          'Make sure the other device is on the same Wi-Fi.',
                    ),

                  if (transferState.status == TransferStatus.error)
                    _buildStatusCard(
                      icon: Icons.error_outline,
                      title: 'Connection Error',
                      subtitle:
                          transferState.errorMessage ??
                          'Unknown error occurred.',
                      color: Colors.redAccent,
                    ),

                  const SizedBox(height: 20),
                  // Share with Section
                  _buildOptionCard(
                    icon: Icons.important_devices_rounded,
                    title: 'Connect to PC',
                    subtitle: transferState.isServerRunning
                        ? Text(
                            'Visit http://${transferState.localIp}:8080 in browser',
                            style: const TextStyle(color: Colors.blueAccent),
                          )
                        : Row(
                            children: [
                              _buildPlatformChip(Icons.smartphone, 'Jio'),
                              _buildPlatformChip(Icons.apple, 'iOS'),
                              _buildPlatformChip(Icons.laptop, 'PC'),
                              _buildPlatformChip(
                                Icons.tablet_android,
                                'Tablet',
                              ),
                            ],
                          ),
                    onTap: () =>
                        _showPcConnectionDialog(context, transferState),
                  ),
                  const SizedBox(height: 15),
                  // History Section
                  _buildOptionCard(
                    icon: Icons.history_rounded,
                    title: 'History',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend(BuildContext context, WidgetRef ref) {
    // For now, show a simulated file picker
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Files to Send',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Feature coming soon: Integration with local video list.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Simulate sending with empty list for logic hook
                  ref.read(transferProvider.notifier).startSend([]);
                },
                child: const Text('Start Sending'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPcConnectionDialog(BuildContext context, TransferState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to PC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.computer, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              '1. Connect your PC to the same Wi-Fi.\n2. Open your browser.\n3. Type this URL:',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'http://${state.localIp ?? "Detecting..."}:8080',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (color ?? Colors.blueAccent).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (color ?? Colors.blueAccent).withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color ?? Colors.blueAccent),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color ?? Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    Widget? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.black87, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformChip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blueAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
