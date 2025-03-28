import 'package:flutter/material.dart';
import 'package:teabot/pages/login_page.dart';
import 'package:teabot/pages/register_page.dart';
import 'package:teabot/pages/splash_screen.dart';
import 'package:teabot/pages/home_page.dart';
import 'package:teabot/pages/chat_page.dart';
import 'package:teabot/pages/profile_settings_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize App Check after Firebase
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
      debugPrint('Firebase App Check initialized successfully');
    } catch (e) {
      debugPrint('Warning: Firebase App Check initialization failed: $e');
      debugPrint('This is expected in development mode');
      // Continue without App Check in development
    }
    
    // Initialize Firebase Storage in background
    Future(() async {
      try {
        final storage = FirebaseStorage.instance;
        final storageRef = storage.ref();
        debugPrint('Firebase Storage initialized successfully');
        debugPrint('Storage bucket: ${storageRef.bucket}');
      } catch (e) {
        debugPrint('Warning: Firebase Storage initialization failed: $e');
      }
    });
    
    debugPrint('Firebase initialized successfully');
    
    // Log initial auth state in background
    Future(() async {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Initial auth state: ${user != null ? 'Authenticated' : 'Not authenticated'}');
      if (user != null) {
        debugPrint('User ID: ${user.uid}');
        debugPrint('User Email: ${user.email}');
        debugPrint('User Display Name: ${user.displayName}');
        debugPrint('User Email Verified: ${user.emailVerified}');
        debugPrint('User Creation Time: ${user.metadata.creationTime}');
        debugPrint('User Last Sign In: ${user.metadata.lastSignInTime}');
      }
    });

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('\n=== Auth State Changed ===');
      debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
      debugPrint('Auth State: ${user != null ? 'Authenticated' : 'Not authenticated'}');
      
      if (user != null) {
        debugPrint('User Details:');
        debugPrint('- ID: ${user.uid}');
        debugPrint('- Email: ${user.email}');
        debugPrint('- Display Name: ${user.displayName}');
        debugPrint('- Email Verified: ${user.emailVerified}');
        debugPrint('- Creation Time: ${user.metadata.creationTime}');
        debugPrint('- Last Sign In: ${user.metadata.lastSignInTime}');
        debugPrint('- Phone Number: ${user.phoneNumber}');
        debugPrint('- Provider Data: ${user.providerData.map((p) => p.providerId).join(', ')}');
      } else {
        debugPrint('No user is currently signed in');
      }
      debugPrint('========================\n');
    });
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        platform: TargetPlatform.android,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Roboto'),
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thickness: MaterialStateProperty.all(6.0),
          thumbColor: MaterialStateProperty.all(Colors.grey[400]),
          radius: const Radius.circular(3.0),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('\n=== Auth State: Waiting ===');
            debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
            debugPrint('Checking authentication state...');
            debugPrint('========================\n');
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasData) {
            final user = snapshot.data;
            debugPrint('\n=== Auth State: Authenticated ===');
            debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
            debugPrint('User Details:');
            debugPrint('- ID: ${user?.uid}');
            debugPrint('- Email: ${user?.email}');
            debugPrint('- Display Name: ${user?.displayName}');
            debugPrint('- Email Verified: ${user?.emailVerified}');
            
            // Allow access even if email is not verified
            debugPrint('User authenticated - proceeding to home page');
            debugPrint('========================\n');
            return HomePage(userName: user?.displayName);
          }
          
          debugPrint('\n=== Auth State: Not Authenticated ===');
          debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
          debugPrint('No user is currently signed in - redirecting to login');
          debugPrint('========================\n');
          return LoginPage();
        },
      ),
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/home': (context) => HomePage(
          userName: FirebaseAuth.instance.currentUser?.displayName,
        ),
        '/profile': (context) => ProfileSettingsPage(),
        '/chat': (context) => ChatPage(),
      },
      onGenerateRoute: (settings) {
        debugPrint('\n=== Route Generation ===');
        debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
        debugPrint('Route: ${settings.name}');
        debugPrint('Arguments: ${settings.arguments}');
        debugPrint('========================\n');
        
        return MaterialPageRoute(
          builder: (context) {
            switch (settings.name) {
              case '/splash':
                return SplashScreen();
              case '/login':
                return LoginPage();
              case '/register':
                return RegisterPage();
              case '/home':
                return HomePage(
                  userName: FirebaseAuth.instance.currentUser?.displayName,
                );
              case '/profile':
                return ProfileSettingsPage();
              case '/chat':
                return ChatPage();
              default:
                return SplashScreen();
            }
          },
        );
      },
    );
  }
}