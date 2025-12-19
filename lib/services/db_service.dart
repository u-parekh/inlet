//import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class DBService {
  static final client = Supa.client;

  // create user
  static Future<void> createUser(Map<String, dynamic> data) async {
    await client.from('users').insert(data);
  }

  static Future<Map<String, dynamic>?> getUserByAuthId(String authId) async {
    final res = await client
        .from('users')
        .select()
        .eq('auth_id', authId)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  static Stream<List<Map<String, dynamic>>> visitorStreamForResident(
      String residentAuthId) {
    return client
        .from('visitors')
        .stream(primaryKey: ['id']) // ✅ required in new SDK
        .eq(
        'resident_auth_id', residentAuthId) // ✅ use filter instead of : syntax
        .order('created_at', ascending: false);
  }

  /*static Stream<List<Map<String, dynamic>>> visitorStreamForResident(String residentAuthId) {
    return client
        .from('visitors:resident_auth_id=eq.$residentAuthId')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        //.execute()
        .map((e) => List<Map<String,dynamic>>.from(e as List));
  }*/

  // create visitor
  static Future<void> createVisitor(Map<String, dynamic> visitor) async {
    await client.from('visitors').insert(visitor);
  }

  // Resident responds to visitor
  static Future<void> respondVisitor(String visitorId, String guardId,
      String visitorName, bool accepted) async {
    final status = accepted ? 'accepted' : 'denied';
    await client.from('visitors').update({'status': status}).eq(
        'id', visitorId);

    // Send notification to guard
    await client.from('notifications').insert({
      'visitor_name': visitorName,
      'status': status,
      'guard_id': guardId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Find resident by block + flat
  static Future<Map<String, dynamic>?> findResidentByBlockFlat(String block,
      String flat) async {
    final res = await client
        .from('users')
        .select()
        .eq('role', 'Resident')
        //.eq('block', block)
        .eq('flat', flat)
        .limit(1);

   // print('Supabase query result: $res');

    if (res.isEmpty) return null;
    return res.first;
  }


  // update visitor status
  static Future<void> updateVisitorStatus(String visitorId,
      String status) async {
    await client.from('visitors').update({'status': status}).eq(
        'id', visitorId);
  }

  static Stream<List<Map<String, dynamic>>> residentVisitorStream(
      String residentAuthId) {
    return client
        .from('visitors') // table name
        .stream(primaryKey: ['id'])
        .eq('resident_auth_id', residentAuthId) // only this resident's visitors
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> visitorsStreamForResident(
      String residentId) {
    return client
        .from('visitors:resident_id=eq.$residentId')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((event) => List<Map<String, dynamic>>.from(event as List));
  }

  static Stream<List<Map<String, dynamic>>> guardVisitorStream(
      String guardAuthId) {
    return client
        .from('visitors') // table name
        .stream(primaryKey: ['id'])
        .eq('guard_auth_id', guardAuthId) // only this guard's visitors
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> guardNotificationsStream(
      String guardId) {
    return client
        .from('notifications:guard_id=eq.$guardId')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((e) => List<Map<String, dynamic>>.from(e as List));
  }

  // notices stream
  /*static Stream<List<Map<String, dynamic>>> noticesStream() {
    return client.from('notices').stream(primaryKey: ['id']).order('created_at', ascending: false).execute()
        .map((e) => List<Map<String,dynamic>>.from(e as List));
  }*/
  static Stream<List<Map<String, dynamic>>> noticesStream() {
    return client
        .from('notice')
        .stream(primaryKey: ['id']) // ✅ required in new SDK
        .order('created_at', ascending: false)
        .map((event) => List<Map<String, dynamic>>.from(event as List));
  }

  // Get all users (except admin)
  static Stream<List<Map<String, dynamic>>> usersStream() {
    return client.from('users').stream(primaryKey: ['id']).order(
        'created_at', ascending: false);
  }

// Get notices created by admin
  static Stream<List<Map<String, dynamic>>> adminNoticesStream(String adminId) {
    return client.from('notices').stream(primaryKey: ['id'])
        .eq('created_by', adminId)
        .order('created_at', ascending: false);
  }

// Create a new notice
  static Future<void> createNotice({
    required String title,
    required String body,
    required String target,
    required String adminId,
  }) async {
    await client.from('notices').insert({
      'title': title,
      'body': body,
      'target': target,
      'created_by': adminId,
    });
  }
}