import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../domain/models/gifticon_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/encryption_service.dart';

part 'gifticon_repository.g.dart';

class GifticonRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 사용자별 전용 서브 컬렉션 경로 반환
  CollectionReference? get _userCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('gifticons');
  }

  Future<void> addGifticon(GifticonModel gifticon) async {
    final collection = _userCollection;
    if (collection == null) throw Exception('로그인이 필요합니다.');

    final userId = _auth.currentUser!.uid;

    // 로컬 저장 방식이므로 별도의 업로드 없이 전달받은 데이터 그대로 사용
    final gifticonToSave = gifticon.copyWith(
      userId: userId,
    );
    
    final data = gifticonToSave.toFirestore();
    
    // 바코드 번호 암호화
    final encryptedBarcode = EncryptionService().encryptText(gifticon.barcodeNumber);
    data['barcodeNumber'] = encryptedBarcode;

    // Firestore에 텍스트 데이터와 로컬 이미지 경로 저장
    if (gifticon.id.isEmpty) {
      await collection.add(data);
    } else {
      await collection.doc(gifticon.id).set(data, SetOptions(merge: true));
    }
  }

  Future<List<GifticonModel>> getGifticons() async {
    final collection = _userCollection;
    if (collection == null) return [];

    // 사용자 전용 서브 컬렉션이므로 전체를 가져와도 본인의 것만 반환됩니다.
    final snapshot = await collection.get();

    final gifticons = snapshot.docs.map((doc) {
      final model = GifticonModel.fromFirestore(doc);
      // 바코드 번호 복호화
      final decryptedBarcode = EncryptionService().decryptText(model.barcodeNumber);
      return model.copyWith(barcodeNumber: decryptedBarcode);
    }).toList();

    // 생성일자 내림차순 정렬 (최신순)
    gifticons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return gifticons;
  }

  Future<void> deleteGifticon(String id) async {
    final collection = _userCollection;
    if (collection == null) return;
    await collection.doc(id).delete();
  }

  Future<void> updateGifticonStatus(String id, bool isUsed) async {
    final collection = _userCollection;
    if (collection == null) return;
    await collection.doc(id).update({'isUsed': isUsed});
  }
}

@riverpod
GifticonRepository gifticonRepository(Ref ref) {
  return GifticonRepository();
}
