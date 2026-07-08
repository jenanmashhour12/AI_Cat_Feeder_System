import 'package:cat_feeder_app/services/firebase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseService enrollment cancellation', () {
    test('includes cat_id when a cat was assigned', () {
      final service = FirebaseService();
      final data = service.buildEnrollmentCommandPayload(
        status: 'cancelled',
        catId: 'cat_003',
      );

      expect(data['status'], 'cancelled');
      expect(data['cat_id'], 'cat_003');
    });

    test('omits cat_id when no cat was assigned', () {
      final service = FirebaseService();
      final data = service.buildEnrollmentCommandPayload(status: 'cancelled');

      expect(data['status'], 'cancelled');
      expect(data.containsKey('cat_id'), isFalse);
    });
  });
}
