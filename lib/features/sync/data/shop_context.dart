import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> resolveCurrentShopId(SupabaseClient client) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Sign in before synchronizing shop data.');
  }
  final membership = await client
      .from('shop_memberships')
      .select('shop_id')
      .eq('user_id', userId)
      .single();
  return membership['shop_id'] as String;
}
