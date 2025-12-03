import 'dart:convert';
import 'api_client.dart';

class UsersApi {
  Future<Map<String, dynamic>> getMe() async {
    // 1. Dane użytkownika
    final userRes = await ApiClient.I.getAuth('/users/me');
    if (userRes.statusCode != 200) throw Exception('User Err: ${userRes.body}');

    final userData = jsonDecode(userRes.body)['data'] as Map<String, dynamic>;

    // 2. Dane emergency
    final emgRes = await ApiClient.I.getAuth('/api/emergency/me');
    Map<String, dynamic> emgData = {};
    if (emgRes.statusCode == 200) {
      final json = jsonDecode(emgRes.body);
      if (json['data'] != null) {
        emgData = json['data'] as Map<String, dynamic>;
      }
    }

    return {...userData, ...emgData};
  }

  Future<void> updateMe({
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bloodType,
    String? allergies, // NOWE
    String? medications, // NOWE
    String? todaysPlan, // NOWE
    String? addressStreet,
    String? addressHouseNumber,
    String? addressPostalCode,
    String? addressCity,
    bool? allowLocationSharing,
  }) async {
    // Payload USER
    final userPayload = <String, dynamic>{};
    if (allowLocationSharing != null)
      userPayload['allow_location_sharing'] = allowLocationSharing;

    if (userPayload.isNotEmpty) {
      await ApiClient.I.putAuth('/users/me', body: jsonEncode(userPayload));
    }

    // Payload EMERGENCY
    final emgPayload = <String, dynamic>{};
    if (phone != null) emgPayload['phone'] = phone;
    if (emergencyContactName != null)
      emgPayload['emergency_contact_name'] = emergencyContactName;
    if (emergencyContactPhone != null)
      emgPayload['emergency_contact_phone'] = emergencyContactPhone;
    if (bloodType != null) emgPayload['blood_type'] = bloodType;
    if (allergies != null) emgPayload['allergies'] = allergies; // NOWE
    if (medications != null) emgPayload['medications'] = medications; // NOWE
    if (todaysPlan != null) emgPayload['todays_plan'] = todaysPlan; // NOWE

    if (addressStreet != null) emgPayload['address_street'] = addressStreet;
    if (addressHouseNumber != null)
      emgPayload['address_house_number'] = addressHouseNumber;
    if (addressPostalCode != null)
      emgPayload['address_postal_code'] = addressPostalCode;
    if (addressCity != null) emgPayload['address_city'] = addressCity;

    if (emgPayload.isNotEmpty) {
      final res = await ApiClient.I.putAuth(
        '/api/emergency/me',
        body: jsonEncode(emgPayload),
      );
      if (res.statusCode != 200) throw Exception('Emg Err: ${res.body}');
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await ApiClient.I.putAuth(
      '/users/password',
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Błąd zmiany hasła');
    }
  }

  Future<void> deleteAccount() async {
    final res = await ApiClient.I.deleteAuth(
      '/users/me',
    ); // <-- Potrzebujemy metody deleteAuth

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Błąd usuwania konta');
    }
  }
}
