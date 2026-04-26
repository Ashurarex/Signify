import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../widgets/custom_button.dart';
import '../state/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraActive = false;
  bool _isGestureActive = false;
  bool _isDetecting = false;
  String _currentIntent = "No clear gesture recognized.";
  String _dynamicGesture = "";
  Timer? _timer;
  
  final FlutterTts _flutterTts = FlutterTts();
  final List<String> _history = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _lastSpokenIntent = "";

  @override
  void initState() {
    super.initState();
    _initCamerasList();
    _initTts();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(_pulseController);
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> _initCamerasList() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint("Camera listing error: \$e");
    }
  }

  Future<void> _startCamera() async {
    // Check and request camera permissions (mobile only)
    if (!kIsWeb) {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        status = await Permission.camera.request();
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Camera Permission'),
              content: const Text('Camera access is required for gesture recognition. Please enable it in the app settings.'),
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
        return;
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to proceed.')),
          );
        }
        return;
      }
    }

    try {
      if (cameras == null || cameras!.isEmpty) {
        await _initCamerasList();
      }
      if (cameras == null || cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera found or permission denied.')),
          );
        }
        return;
      }

      var camera = cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras!.first,
      );
      
      _controller = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraActive = true;
          _currentIntent = "Camera started. Ready.";
        });
      }
    } catch (e) {
      debugPrint("Camera initialization error: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: \$e')),
        );
      }
    }
  }

  Future<void> _stopCamera() async {
    _stopGesture();
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    if (mounted) {
      setState(() {
        _isCameraActive = false;
        _currentIntent = "Camera stopped.";
        _dynamicGesture = "";
      });
    }
  }

  void _startGesture() {
    if (!_isCameraActive || _controller == null) return;
    setState(() {
      _isGestureActive = true;
      _currentIntent = "Detecting gestures...";
    });
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      _processCameraFrame();
    });
  }

  void _stopGesture() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _isGestureActive = false;
        _currentIntent = "Gesture detection stopped.";
      });
    }
  }

  Future<void> _processCameraFrame() async {
    if (_controller == null || !_controller!.value.isInitialized || _isDetecting || !_isGestureActive) return;

    setState(() { _isDetecting = true; });

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/predict_image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            String newIntent = data['message'] ?? 'No clear gesture recognized.';
            _dynamicGesture = data['dynamic_gesture'] ?? '';
            
            if (newIntent != _currentIntent && newIntent != 'No clear gesture recognized.') {
               _history.insert(0, newIntent);
               if (_history.length > 5) _history.removeLast();
               
               if (_lastSpokenIntent != newIntent) {
                 _flutterTts.speak(newIntent);
                 _lastSpokenIntent = newIntent;
               }

               if (!kIsWeb) {
                 Vibration.hasVibrator().then((hasVibrator) {
                   if (hasVibrator == true) {
                     Vibration.vibrate(duration: 50);
                   }
                 }).catchError((e) => debugPrint("Vibration error: \$e"));
               }
            }
            _currentIntent = newIntent;
            
            // Auto-navigate to SOS if emergency is detected
            if (data['intent'] == 'SOS') {
              Navigator.pushNamed(context, '/sos');
            }
          });
        }
      }
    } catch (e) {
      debugPrint("API error: \$e");
    } finally {
      if (mounted) {
        setState(() { _isDetecting = false; });
      }
    }
  }

  Future<void> _saveSessionToCloud() async {
    if (_history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No gesture history to save!')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save sessions.')),
      );
      return;
    }

    // Show non-blocking snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading session to cloud in background...')),
    );

    // Capture context variables we need
    final currentHistory = List<String>.from(_history);
    final uid = user.uid;

    // Run asynchronously to not block the UI
    Future.microtask(() async {
      try {
        final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        
        // 1. Generate PDF (can be slow on web)
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Signify - Medical / Legal Session Transcript', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('Date: \${DateTime.now().toLocal()}'),
                  pw.Text('User ID: \$uid'),
                  pw.SizedBox(height: 20),
                  pw.Text('Interpreted Gestures:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  ...currentHistory.map((phrase) => pw.Bullet(text: phrase)).toList(),
                ],
              );
            },
          ),
        );
        final pdfBytes = await pdf.save();

        // 2. Upload to Firebase Storage with timeout
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/\$uid/sessions/\$sessionId.pdf');
        
        await storageRef.putData(
          pdfBytes,
          SettableMetadata(contentType: 'application/pdf'),
        ).timeout(const Duration(seconds: 15));
        
        final downloadUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 10));

        // 3. Save to Firestore with timeout
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sessions')
            .doc(sessionId)
            .set({
          'timestamp': FieldValue.serverTimestamp(),
          'history': currentHistory,
          'pdfUrl': downloadUrl,
        }).timeout(const Duration(seconds: 10));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Session successfully saved to cloud!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint("Cloud save error: \$e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('❌ Cloud upload failed. Check Firebase Rules or Network. Error: \$e'),
               backgroundColor: Colors.red,
               duration: const Duration(seconds: 5),
             ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _flutterTts.stop();
    _pulseController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  AudioPlayer? _audioPlayer;
  bool _isEmergencyDebounced = false;

  void _triggerEmergency() {
    if (_isEmergencyDebounced) return;
    _isEmergencyDebounced = true;
    _showEmergencyOverlay();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _isEmergencyDebounced = false;
      }
    });
  }

  void _showEmergencyOverlay() {
    _audioPlayer ??= AudioPlayer();
    _audioPlayer!.setReleaseMode(ReleaseMode.loop);
    _audioPlayer!.play(AssetSource('siren.ogg'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'EMERGENCY MODE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setModalState) {
                    return _LocationShareWidget(
                      contacts: AppState.emergencyContactsNotifier.value,
                    );
                  }
                ),
              ),
              Expanded(
                flex: 3,
                child: ValueListenableBuilder<List<Map<String, String>>>(
                  valueListenable: AppState.emergencyContactsNotifier,
                  builder: (context, contacts, child) {
                    if (contacts.isEmpty) {
                      return const Center(
                        child: Text(
                          'No emergency contacts added.\nPlease add them in Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red.shade200, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Icon(Icons.person, color: Colors.red.shade700),
                            ),
                            title: Text(
                              contact['name'] ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              contact['phone'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () async {
                                final phone = contact['phone'] ?? '';
                                final uri = Uri.parse('tel:\$phone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              icon: const Icon(Icons.call),
                              label: const Text('CALL'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _audioPlayer?.stop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.volume_off, size: 28),
                        label: const Text('STOP SIREN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CLOSE EMERGENCY OVERLAY', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _audioPlayer?.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppState.getString('app_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Colors.brown),
            tooltip: 'Save Session',
            onPressed: _saveSessionToCloud,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.brown),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.brown),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main Card (Camera preview)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isCameraActive && _controller != null && _controller!.value.isInitialized)
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: CameraPreview(_controller!),
                        )
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text('Camera is stopped.', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      // Glassmorphic HUD overlay
                      if (_isCameraActive && _isGestureActive)
                        Positioned.fill(
                           child: CustomPaint(
                             painter: HudPainter(animation: _pulseAnimation),
                           ),
                        ),
                      // Status Overlay
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(color: Colors.greenAccent.withOpacity(0.1), blurRadius: 8),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _isGestureActive ? (_isDetecting ? Colors.orange : Colors.greenAccent) : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dynamicGesture.isNotEmpty ? 'Gesture: \$_dynamicGesture' : (_isGestureActive ? 'Status: Active' : 'Status: Idle'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isDetecting)
                                    const Text("Conf: 94%", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentIntent,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Camera & Gesture Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_isCameraActive)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startCamera,
                      icon: const Icon(Icons.videocam),
                      label: Text(AppState.getString('start_camera')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stopCamera,
                      icon: const Icon(Icons.videocam_off),
                      label: Text(AppState.getString('stop_camera')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                if (_isCameraActive)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGestureActive ? _stopGesture : _startGesture,
                      icon: Icon(_isGestureActive ? Icons.stop_circle : Icons.play_circle_fill),
                      label: Text(_isGestureActive ? AppState.getString('stop_gesture') : AppState.getString('start_gesture')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _isGestureActive ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_history.isNotEmpty)
              Container(
                height: 40,
                width: double.infinity,
                child: ListView.builder(
                   scrollDirection: Axis.horizontal,
                   itemCount: _history.length,
                   itemBuilder: (context, index) {
                      return Padding(
                         padding: const EdgeInsets.only(right: 8.0),
                         child: Chip(
                            label: Text(_history[index]),
                            backgroundColor: Colors.green.withOpacity(0.2),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                         ),
                      );
                   },
                ),
              ),
            const SizedBox(height: 16),
            // Standalone Emergency Button
            InkWell(
              onTap: _triggerEmergency,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade700, Colors.red.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_rounded, size: 36, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      AppState.getString('emergency').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class HudPainter extends CustomPainter {
  final Animation<double> animation;
  HudPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    double cornerLength = 30.0;
    
    // Top Left
    canvas.drawLine(const Offset(20, 20), Offset(20 + cornerLength, 20), paint);
    canvas.drawLine(const Offset(20, 20), Offset(20, 20 + cornerLength), paint);
    
    // Top Right
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20 - cornerLength, 20), paint);
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20, 20 + cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(20, size.height - 20), Offset(20 + cornerLength, size.height - 20), paint);
    canvas.drawLine(Offset(20, size.height - 20), Offset(20, size.height - 20 - cornerLength), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width - 20, size.height - 20), Offset(size.width - 20 - cornerLength, size.height - 20), paint);
    canvas.drawLine(Offset(size.width - 20, size.height - 20), Offset(size.width - 20, size.height - 20 - cornerLength), paint);

    // Scanning Line
    final linePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(1.0 - animation.value)
      ..strokeWidth = 2.0;
    double lineY = 20 + (size.height - 40) * animation.value;
    canvas.drawLine(Offset(20, lineY), Offset(size.width - 20, lineY), linePaint);
  }

  @override
  bool shouldRepaint(HudPainter oldDelegate) => true;
}

class _LocationShareWidget extends StatefulWidget {
  final List<Map<String, String>> contacts;
  
  const _LocationShareWidget({required this.contacts});

  @override
  State<_LocationShareWidget> createState() => _LocationShareWidgetState();
}

class _LocationShareWidgetState extends State<_LocationShareWidget> {
  String _status = "Initializing...";
  bool _isLoading = true;
  bool _hasError = false;
  Position? _currentPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _processLocation();
  }

  Future<void> _processLocation() async {
    try {
      if (widget.contacts.isEmpty) {
        setState(() {
          _status = "No contacts to share location with.";
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      setState(() {
        _status = "Checking location permissions...";
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _status = "Location services are disabled.";
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _status = "Location permissions denied.";
            _isLoading = false;
            _hasError = true;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _status = "Location access is required to share your live location during emergencies.";
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      setState(() {
        _status = "Fetching location...";
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
        _status = "Sending alerts...";
      });

      String mapsLink = "https://www.google.com/maps?q=\${position.latitude},\${position.longitude}";
      String message = "Emergency! I need help. Here is my live location: \$mapsLink";

      for (var contact in widget.contacts) {
        final phone = contact['phone'] ?? '';
        if (phone.isNotEmpty) {
          final uri = Uri.parse('sms:\$phone?body=\${Uri.encodeComponent(message)}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      }

      if (mounted) {
        setState(() {
          _status = "Location shared successfully";
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "Unable to fetch location";
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          color: _hasError ? Colors.orange.shade100 : (_isLoading ? Colors.blue.shade50 : Colors.green.shade50),
          child: Row(
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_hasError)
                const Icon(Icons.error_outline, color: Colors.orange)
              else
                const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _hasError ? Colors.orange.shade800 : (_isLoading ? Colors.blue.shade800 : Colors.green.shade800),
                  ),
                ),
              ),
              if (_hasError)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                    _processLocation();
                  },
                  child: const Text('RETRY'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _currentPosition != null
              ? FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    initialZoom: 16.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.signify',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.map, size: 64, color: Colors.grey),
                  ),
                ),
        ),
      ],
    );
  }
}
