import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_ivs_player/flutter_ivs_player.dart';
import 'package:stripe_payment/stripe_payment.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SignInScreen(),
    );
  }
}

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadVideo(String userId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);

    if (result != null) {
      final file = result.files.single;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final uploadTask = _storage.ref('videos/$fileName').putData(file.bytes!);

      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();
      return videoUrl;
    } else {
      return null;
    }
  }
}

class VideoStreamingScreen extends StatelessWidget {
  final String videoUrl;

  VideoStreamingScreen({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController _controller = VideoPlayerController.network(videoUrl)
      ..initialize().then((_) {
        _controller.play();
      });

    return Scaffold(
      appBar: AppBar(title: Text('Video Streaming')),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : CircularProgressIndicator(),
      ),
    );
  }
}

class VideoManagementScreen extends StatefulWidget {
  final String userId;

  VideoManagementScreen({required this.userId});

  @override
  _VideoManagementScreenState createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen> {
  final VideoUploadService _uploadService = VideoUploadService();
  List<String> _uploadedVideos = [];

  Future<void> _uploadVideo() async {
    final videoUrl = await _uploadService.uploadVideo(widget.userId);
    if (videoUrl != null) {
      setState(() {
        _uploadedVideos.add(videoUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video uploaded successfully!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video upload failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Videos')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _uploadVideo,
            child: Text('Upload Video'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _uploadedVideos.length,
              itemBuilder: (context, index) {
                final videoUrl = _uploadedVideos[index];
                return ListTile(
                  title: Text('Video ${index + 1}'),
                  trailing: IconButton(
                    icon: Icon(Icons.play_circle_fill),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => VideoStreamingScreen(videoUrl: videoUrl)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _signIn() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoManagementScreen(userId: userCredential.user!.uid),
        ),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign-in failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: _signIn,
              child: Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
