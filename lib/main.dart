import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderApp extends StatefulWidget {
  const AudioRecorderApp({super.key});

  @override
  _AudioRecorderAppState createState() => _AudioRecorderAppState();
}

class _AudioRecorderAppState extends State<AudioRecorderApp> {
  static const platform = MethodChannel('audio.device.control');
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  List<FileSystemEntity> _audioFiles = [];
  String? _currentPlayingFile;
  String? _selectedInputDevice;
  List<String> _availableDevices = []; // List of available audio input devices
  Timer? _deviceUpdateTimer; // Timer for periodic device update

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _fetchAudioFiles();
    _fetchInputDevices();
    _player.openPlayer();

    // Periodically update the available devices every 5 seconds
    _deviceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchInputDevices();
    });
  }

  @override
  void dispose() {
    _deviceUpdateTimer?.cancel(); // Cancel the timer when the app is disposed
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      print("Microphone permission is required");
      return;
    }

    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<String> _getFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return "${directory.path}/$fileName";
  }

  Future<void> _fetchAudioFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().where((file) => file.path.endsWith(".aac")).toList();
    setState(() {
      _audioFiles = files;
    });
  }

  Future<void> _fetchInputDevices() async {
    try {
      final devices = await platform.invokeMethod<List>('getInputDevices');
      setState(() {
        _availableDevices = devices?.cast<String>() ?? [];
        if (_availableDevices.isNotEmpty) {
          if (_selectedInputDevice == null) {
            _selectedInputDevice = _availableDevices.first;
          }
        }
      });
    } catch (e) {
      print("Error fetching input devices: $e");
    }
  }

  Future<void> _setInputDevice(String device) async {
    try {
      await platform.invokeMethod('setInputDevice', {"device": device});
    } catch (e) {
      print("Error setting input device: $e");
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) {
      print("Recorder not initialized");
      return;
    }

    if (_selectedInputDevice != null) {
      await _setInputDevice(_selectedInputDevice!);
    }

    final fileName = "audio_${DateTime.now().millisecondsSinceEpoch}.aac";
    final path = await _getFilePath(fileName);

    try {
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print("Error starting recorder: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized) return;

    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });

    _fetchAudioFiles();
  }

  Future<void> _playAudio(String filePath) async {
    try {
      if (_isPlaying && _currentPlayingFile == filePath) {
        await _player.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
        return;
      }

      if (_isPlaying && _currentPlayingFile != filePath) {
        await _player.stopPlayer();
      }

      await _player.startPlayer(
        fromURI: filePath,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
            _currentPlayingFile = null;
          });
        },
      );

      setState(() {
        _isPlaying = true;
        _currentPlayingFile = filePath;
      });
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentPlayingFile = null;
      });
    } catch (e) {
      print("Error stopping audio: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audio Recorder with Device Selection"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Device Dropdown
            Row(
              children: [
                const Text("Input Device:"),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedInputDevice,
                  onChanged: (device) {
                    setState(() {
                      _selectedInputDevice = device;
                    });
                  },
                  items: _availableDevices.map((device) {
                    return DropdownMenuItem<String>(
                      value: device,
                      child: Text(device),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Record Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? "Stop Recording" : "Record"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Audio File List
            Expanded(
              child: _audioFiles.isEmpty
                  ? const Center(
                child: Text(
                  "No recordings yet.",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _audioFiles.length,
                itemBuilder: (context, index) {
                  final file = _audioFiles[index];
                  final fileName = file.path.split("/").last;

                  return Card(
                    elevation: 3,
                    child: ListTile(
                      title: Text(fileName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlaying && _currentPlayingFile == file.path
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () => _playAudio(file.path),
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: () => _stopAudio(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AudioRecorderApp(),
  ));
}
