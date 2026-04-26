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

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _flutterTts.stop();
    _pulseController.dispose();
    super.dispose();
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
              onTap: () {
                Navigator.pushNamed(context, '/sos');
              },
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

