import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class LinkingCodeInfo {
  final String code;
  final String tenantId;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? linkedUid;
  final String? deviceName;

  LinkingCodeInfo({
    required this.code,
    required this.tenantId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.linkedUid,
    this.deviceName,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == 'pending';
  bool get isLinked => status == 'linked';
  bool get isApproved => status == 'approved';
}

class DeviceLinkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final code = List.generate(6, (i) {
      final idx = (random >> (i * 5)) % chars.length;
      return chars[idx.abs()];
    }).join();
    return code;
  }

  Future<String> generateLinkingCode(String tenantId) async {
    final code = _generateCode();
    final now = DateTime.now();
    await _firestore.collection('linking_codes').doc(code).set({
      'tenantId': tenantId,
      'status': 'pending',
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'createdBy': _uid,
    });
    return code;
  }

  Future<LinkingCodeInfo?> getLinkingCode(String code) async {
    try {
      final doc = await _firestore.collection('linking_codes').doc(code).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return LinkingCodeInfo(
        code: code,
        tenantId: data['tenantId'] as String,
        status: data['status'] as String? ?? 'pending',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        expiresAt: (data['expiresAt'] as Timestamp).toDate(),
        linkedUid: data['linkedUid'] as String?,
        deviceName: data['deviceName'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Stream<LinkingCodeInfo?> watchLinkingCode(String code) {
    return _firestore.collection('linking_codes').doc(code).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return null;
        final data = snapshot.data()!;
        return LinkingCodeInfo(
          code: code,
          tenantId: data['tenantId'] as String,
          status: data['status'] as String? ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          expiresAt: (data['expiresAt'] as Timestamp).toDate(),
          linkedUid: data['linkedUid'] as String?,
          deviceName: data['deviceName'] as String?,
        );
      },
    );
  }

  Future<bool> submitLinkingRequest(String code, String deviceName) async {
    try {
      if (_uid.isEmpty) return false;
      final info = await getLinkingCode(code);
      if (info == null || info.isExpired || !info.isPending) return false;

      await _firestore.collection('linking_codes').doc(code).update({
        'linkedUid': _uid,
        'deviceName': deviceName,
        'status': 'linked',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> approveLinking(String code, {required bool isAdmin}) async {
    try {
      final info = await getLinkingCode(code);
      if (info == null || info.linkedUid == null) return false;

      final linkedUid = info.linkedUid!;
      final tenantId = info.tenantId;

      final batch = _firestore.batch();
      final targetCollection = isAdmin ? 'admins' : 'cashiers';
      final ref = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection(targetCollection)
          .doc(linkedUid);
      batch.set(ref, {
        'linkedAt': Timestamp.fromDate(DateTime.now()),
        'deviceName': info.deviceName ?? 'Unknown device',
        'role': targetCollection,
      });

      final codeRef = _firestore.collection('linking_codes').doc(code);
      batch.update(codeRef, {
        'status': 'approved',
        'approvedAt': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectLinking(String code) async {
    try {
      await _firestore.collection('linking_codes').doc(code).update({
        'status': 'rejected',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<LinkingCodeInfo>> getActiveCodes(String tenantId) async {
    try {
      final snapshot = await _firestore
          .collection('linking_codes')
          .where('tenantId', isEqualTo: tenantId)
          .where('status', whereIn: ['pending', 'linked'])
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return LinkingCodeInfo(
          code: doc.id,
          tenantId: data['tenantId'] as String,
          status: data['status'] as String? ?? 'pending',
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          expiresAt: (data['expiresAt'] as Timestamp).toDate(),
          linkedUid: data['linkedUid'] as String?,
          deviceName: data['deviceName'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> signInAnonymously() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<bool> isSignedInToFirebase() async {
    return _auth.currentUser != null;
  }

  Future<void> signOut() async {
    if (_auth.currentUser?.isAnonymous == true) {
      await _auth.signOut();
    }
  }
}
