import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/gifticon_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'gifticon_repository.g.dart';

class GifticonRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 사용자 고유 컬렉션 경로를 얻을 수 있지만, 현재는 익명/로컬 테스트이므로
  // 공용 'gifticons' 컬렉션을 사용하거나, 기기 ID 기반 컬렉션을 사용할 수 있습니다.
  // 여기서는 단순함을 위해 'gifticons' 컬렉션을 사용합니다.
  CollectionReference get _collection => _firestore.collection('gifticons');

  Future<void> addGifticon(GifticonModel gifticon) async {
    // ID가 빈 문자열이면 새로 생성, 아니면 해당 ID로 덮어쓰기
    if (gifticon.id.isEmpty) {
      await _collection.add(gifticon.toFirestore());
    } else {
      await _collection.doc(gifticon.id).set(gifticon.toFirestore());
    }
  }

  Future<List<GifticonModel>> getGifticons() async {
    final snapshot = await _collection.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => GifticonModel.fromFirestore(doc)).toList();
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
