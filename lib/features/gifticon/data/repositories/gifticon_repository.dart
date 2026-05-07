import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/gifticon_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/encryption_service.dart';

part 'gifticon_repository.g.dart';

class GifticonRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 공용 'gifticons' 컬렉션 사용
  CollectionReference get _collection => _firestore.collection('gifticons');

  // 현재 로그인한 사용자의 UID 가져오기
  String? get _currentUserId => _auth.currentUser?.uid;

  Future<void> addGifticon(GifticonModel gifticon) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('로그인이 필요합니다.');

    final data = gifticon.copyWith(userId: userId).toFirestore();
    
    // 바코드 번호 암호화
    final encryptedBarcode = EncryptionService().encryptText(gifticon.barcodeNumber);
    data['barcodeNumber'] = encryptedBarcode;

    if (gifticon.id.isEmpty) {
      await _collection.add(data);
    } else {
      await _collection.doc(gifticon.id).set(data, SetOptions(merge: true));
    }
  }

  Future<List<GifticonModel>> getGifticons() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    // 인덱스 오류 방지를 위해 서버 정렬(orderBy) 대신 전체를 가져온 뒤 메모리에서 정렬합니다.
    final snapshot = await _collection
        .where('userId', isEqualTo: userId)
        .get();

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
    await _collection.doc(id).delete();
  }

  Future<void> updateGifticonStatus(String id, bool isUsed) async {
    await _collection.doc(id).update({'isUsed': isUsed});
  }
}

@riverpod
GifticonRepository gifticonRepository(Ref ref) {
  return GifticonRepository();
}
