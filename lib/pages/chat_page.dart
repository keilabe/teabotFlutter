import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:teabot/services/chat_service.dart';
import 'package:teabot/services/disease_detection_service.dart';

class ChatPage extends StatefulWidget {
  final String? initialDisease;
  final double? initialConfidence;
  final File? imageFile;
  final String? imageUrl;

  const ChatPage({
    Key? key,
    this.initialDisease,
    this.initialConfidence,
    this.imageFile,
    this.imageUrl,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
  bool _hasUploadedImage = false;
  String? _currentImageUrl;
  String _analysisStatus = 'pending';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentDisease;
  File? _imageFile;
  bool _isProcessing = false;
  double? _confidence;

  final List<String> _predefinedQuestions = [
    "What is the disease?",
    "What is the cause of the disease?",
    "What are the possible curatives?",
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _checkForUploadedImage();
    _initializeChat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    debugPrint('\n=== Initializing Chat ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    // Add initial message with image placeholder
    _messages.add(ChatMessage(
      text: 'Welcome! Please select an image of a tea leaf to analyze.',
      isUser: false,
      timestamp: DateTime.now(),
      hasImage: true,
      imageFile: null,
      imageUrl: 'assets/images/placeholder_leaf.jpg',
    ));
    
    setState(() {});
    debugPrint('=== Chat Initialization Completed ===\n');
    return;
  }

  void _showDefaultQuestions() {
    final disease = widget.initialDisease?.toLowerCase();
    final questions = [
      'What is ${widget.initialDisease}?',
      'What are the symptoms of ${widget.initialDisease}?',
      'How can I treat ${widget.initialDisease}?',
      'What causes ${widget.initialDisease}?',
    ];

    setState(() {
      _messages.add(ChatMessage(
        text: 'Here are some questions you can ask about ${widget.initialDisease}:',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      for (final question in questions) {
        _messages.add(ChatMessage(
          text: question,
          isUser: false,
          isQuestion: true,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _checkForUploadedImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final latestImage = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .orderBy('uploadedAt', descending: true)
          .limit(1)
          .get();

      if (latestImage.docs.isNotEmpty) {
        final imageData = latestImage.docs.first.data();
        setState(() {
          _hasUploadedImage = true;
          _currentImageUrl = imageData['imageUrl'];
          _analysisStatus = imageData['status'] ?? 'pending';
        });
        _animationController.forward();
        
        // Listen for status updates
        final imageId = latestImage.docs.first.id;
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('images')
            .doc(imageId)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.exists) {
            setState(() {
              _analysisStatus = snapshot.data()?['status'] ?? 'pending';
            });
          }
        });
      }
    }
  }

  Widget _buildAnalysisStatus() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_analysisStatus) {
      case 'analyzing':
        statusColor = Colors.blue;
        statusIcon = Icons.analytics;
        statusText = 'Analyzing image...';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Analysis complete';
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Analysis failed';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Waiting for analysis';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImageUploadOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isValidImageType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png'].contains(ext);
  }

  Future<bool> _showImagePreview(File imageFile) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(imageFile),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Upload'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to upload images')),
        );
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      if (!_isValidImageType(pickedFile.path)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid image file (JPG, JPEG, or PNG)')),
        );
        return;
      }

      File? imageFile = File(pickedFile.path);
      
      // Compress image
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );
      
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
        return;
      }
      
      imageFile = File(result.path);
      
      // Show preview and get confirmation
      final shouldUpload = await _showImagePreview(imageFile);
      if (shouldUpload != true) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Create base directory if it doesn't exist
      final storageRef = FirebaseStorage.instance.ref();
      final baseDir = storageRef.child('chat_images/${user.uid}');
      
      // Upload file
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final uploadTask = baseDir.child(fileName).putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/${path.extension(imageFile.path).substring(1)}',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Update progress if needed
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .add({
            'imageUrl': downloadUrl,
            'uploadedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

      setState(() {
        _hasUploadedImage = true;
        _currentImageUrl = downloadUrl;
        _analysisStatus = 'pending';
      });

      // Close loading indicator
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: ${e.toString()}')),
      );
    }
  }

  Future<void> _captureImage() async {
    debugPrint('\n=== Starting Image Capture ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        debugPrint('Image captured from camera: ${image.path}');
        await _processSelectedImage(File(image.path));
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showError('Failed to capture image: $e');
    }
    return;
  }

  Future<void> _pickImage() async {
    debugPrint('\n=== Starting Image Selection ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        debugPrint('Image selected from gallery: ${image.path}');
        await _processSelectedImage(File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showError('Failed to pick image: $e');
    }
    return;
  }

  Future<void> _processSelectedImage(File imageFile) async {
    debugPrint('\n=== Processing Selected Image ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Image path: ${imageFile.path}');
    
    setState(() {
      _isProcessing = true;
      _imageFile = imageFile;
    });

    try {
      // Add user's image message
      _messages.add(ChatMessage(
        text: 'Processing image...',
        isUser: true,
        timestamp: DateTime.now(),
        hasImage: true,
        imageFile: imageFile,
      ));
      setState(() {});

      // Detect disease
      final result = await DiseaseDetectionService.detectDisease(
        imageFile: imageFile,
      );

      setState(() {
        _currentDisease = result['disease'];
        _confidence = result['confidence'];
        _isProcessing = false;
      });

      // Add detection result message
      _messages.add(ChatMessage(
        text: 'Disease detected: ${_currentDisease} (${(_confidence! * 100).toStringAsFixed(1)}% confidence)',
        isUser: false,
        timestamp: DateTime.now(),
      ));

      // Add default questions
      _addDefaultQuestions();
      
      setState(() {});
      debugPrint('=== Image Processing Completed ===\n');
    } catch (e) {
      debugPrint('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to process image: $e');
    }
    return;
  }

  void _addDefaultQuestions() {
    debugPrint('\n=== Adding Default Questions ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    
    final questions = [
      'What are the symptoms of ${_currentDisease}?',
      'How can I treat ${_currentDisease}?',
      'What causes ${_currentDisease}?',
      'How can I prevent ${_currentDisease}?',
    ];

    _messages.add(ChatMessage(
      text: 'Here are some questions you can ask about ${_currentDisease}:',
      isUser: false,
      timestamp: DateTime.now(),
    ));

    for (final question in questions) {
      _messages.add(ChatMessage(
        text: question,
        isUser: false,
        timestamp: DateTime.now(),
        isQuestion: true,
      ));
    }
    
    setState(() {});
    debugPrint('=== Default Questions Added ===\n');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleMessage([String? messageText]) async {
    final text = messageText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    debugPrint('\n=== Processing Chat Message ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('Message: $text');
    debugPrint('Current Disease: $_currentDisease');

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
    });

    try {
      final response = await ChatService.getResponse(
        message: text,
        disease: _currentDisease,
      );
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      debugPrint('=== Message Processing Completed ===\n');
    } catch (e) {
      debugPrint('Error getting response: $e');
      _showError('Failed to get response: $e');
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tea Disease Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _captureImage,
            tooltip: 'Capture Image',
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickImage,
            tooltip: 'Pick Image',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/placeholder_leaf.jpg',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Select an image to analyze',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Upload Image'),
                            ),
                            const SizedBox(width: 20),
                            ElevatedButton.icon(
                              onPressed: _captureImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Capture Image'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatBubble(
                        message: message,
                        onQuestionTap: message.isQuestion ? (question) async {
                          await _handleMessage(question);
                          return;
                        } : null,
                      );
                    },
                  ),
          ),
          if (_currentDisease != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _handleMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isQuestion;
  final DateTime timestamp;
  final bool hasImage;
  final File? imageFile;
  final String? imageUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isQuestion = false,
    required this.timestamp,
    this.hasImage = false,
    this.imageFile,
    this.imageUrl,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(String)? onQuestionTap;

  const ChatBubble({
    required this.message,
    this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: message.isQuestion && onQuestionTap != null
          ? () => onQuestionTap!(message.text)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.green[100]
              : message.isQuestion
                  ? Colors.blue[50]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: message.isQuestion
              ? Border.all(color: Colors.blue[300]!, width: 1)
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isQuestion ? Colors.blue[700] : null,
            fontWeight: message.isQuestion ? FontWeight.w500 : null,
          ),
        ),
      ),
    );
  }
}