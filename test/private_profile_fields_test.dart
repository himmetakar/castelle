import 'package:flutter_test/flutter_test.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/services/private_profile_fields.dart';

void main() {
  test('takePrivateFields hassas alanları kök dokümandan söker', () {
    final data = UserModel(
      uid: 'u1',
      email: 'a@b.com',
      fullName: 'Ada',
      phone: '5551112233',
      role: UserRole.actor,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      guardianPhone: '5559998877',
    ).toMap();

    final private = takePrivateFields(data);

    for (final key in kPrivateProfileFields) {
      expect(data.containsKey(key), isFalse, reason: key);
    }
    expect(private['phone'], '5551112233');
    expect(private['guardianPhone'], '5559998877');
    expect(data['fullName'], 'Ada');
  });
}
