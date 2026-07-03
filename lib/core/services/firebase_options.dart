import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD1AqbeRIt92iFJU6teujcMwWNup6Kdh-o',
    appId: '1:1053407529306:web:b612c17ef5e818c0d5cb63',
    messagingSenderId: '1053407529306',
    projectId: 'tikach-pos',
    authDomain: 'tikach-pos.firebaseapp.com',
    storageBucket: 'tikach-pos.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB27xbWJDELi-GLRgLUPHlTx7f0TD3H1Zg',
    appId: '1:1053407529306:android:5ec7835abc91ad8fd5cb63',
    messagingSenderId: '1053407529306',
    projectId: 'tikach-pos',
    storageBucket: 'tikach-pos.firebasestorage.app',
  );
}
