import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/logout_helper.dart';
import '../../services/db_service.dart';
import 'resident_visitors_page.dart';
import '../profile_page.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notice_card.dart';
import '../../services/fcm_service.dart';
//import 'resident_message_page.dart';
import 'resident_chat_page.dart';

/*Future<void> saveUserFcmToken() async {
  final fcm = FirebaseMessaging.instance;
  final token = await fcm.getToken();
  debugPrint("🔑 FCM Token: $token");

  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user != null && token != null) {
    await supabase
        .from('users')
        .update({'fcm_token': token})
        .eq('auth_id', user.id);
  }
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final uid = supabase.auth.currentUser?.id;
    if (newToken != null && uid != null) {
      await supabase.from('users').update({'fcm_token': newToken}).eq('auth_id', uid);
    }
  });
}*/


class ResidentHome extends StatefulWidget {
  const ResidentHome({super.key});

  @override

  State<ResidentHome> createState() => _ResidentHomeState();
}

class _ResidentHomeState extends State<ResidentHome> {
  int _selectedIndex = 0;
  Map<String, dynamic>? resident;

  @override
  void initState() {
    super.initState();
    FcmService.saveFcmToken();
    //loadResident();
    //String id;
    //final user = Supabase.instance.client.auth.currentUser;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      // update token if refreshed
      //String id;
      Supabase.instance.client
          .from('users')
          .update({'fcm_token': newToken})
          .filter('auth_id::text', 'eq', Supabase.instance.client.auth.currentUser?.id);
          //.eq('auth_id', user.id);
    });
    FirebaseMessaging.onMessage.listen((message) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.notification?.body ?? ''))
      );
    });
  }
  Future<void> loadResident() async {
    final auth = Supabase.instance.client.auth.currentUser!;

    final data = await Supabase.instance.client
        .from('users')
        .select('*')
        .eq('auth_id', auth.id)
        .single();

    setState(() {
      resident = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    /*final user = supabase.auth.currentUser!;
    final residentData = await supabase
        .from('users')
        .select('*')
        .eq('auth_id', user.id)
        .single();*/

    // ✅ If resident data is still loading, show loader
    if (resident == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Define pages
    final List<Widget> pages = [
      _HomeTab(auth: auth),
      const ResidentVisitorsPage(),
      ResidentChatPage(resident: resident!),
      const ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white, // light gray background
        foregroundColor: Colors.white, // deep blue text/icons
        elevation: 0, // flat look
        centerTitle: true, // ✅ centers the title text
        title: const Text(
          'Resident Dashboard',
          style: TextStyle(
            fontSize: 20,
           // fontWeight: FontWeight.bold,
            color: Colors.black, // same as foreground for harmony
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        actions: [
          IconButton(
            icon:Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => LogoutHelper.logout(context),
          ),
        ],
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/icon/icon.png', // 👈 ensure this exists
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: Colors.blueAccent.withOpacity(0.15),
              labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
                    (states) => TextStyle(
                  fontSize: 12,
                  fontWeight:
                  states.contains(MaterialState.selected)
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              height: 65,
              destinations: [
                NavigationDestination(
                  icon: _selectedIndex == 0
                      ? Lottie.asset('assets/lottie/Home Icon.json', height: 36)
                      : const Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: _selectedIndex == 1
                      ? Lottie.asset('assets/lottie/Users icons.json', height: 36)
                      : const Icon(Icons.people_outline),
                  label: 'Visitors',
                ),
                NavigationDestination(
                  icon: _selectedIndex == 2
                      ? Lottie.asset('assets/lottie/Chit Chatting.json', height: 36)
                      : const Icon(Icons.chat_outlined),
                  label: 'Messages',
                ),
                NavigationDestination(
                  icon: _selectedIndex == 3
                      ? Lottie.asset('assets/lottie/user icon.json', height: 34)
                      : const Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🏠 HOME TAB CONTENT
class _HomeTab extends StatelessWidget {
  final AuthService auth;

  const _HomeTab({required this.auth});

  @override

  Widget build(BuildContext context) {
    return Column(
      children: [
        // Welcome Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blueAccent.withOpacity(0.1),
          child: Text(
            'Welcome, ${auth.currentUser?.fullName ?? 'Resident'} 👋',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ✅ Centered "Notice" Title
        const Text(
          "Notice",
          //textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
           // fontWeight: FontWeight.bold,
            //color: Colors.blueGrey,
          ),
        ),

        const SizedBox(height: 8),

        // ✅ Notices List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DBService.noticesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No notices available'));
              }

              final notices = snapshot.data!;
              return ListView.builder(
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  return NoticeCard(notice: notices[index]); // ✅ Custom Card
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


/*class _HomeTab extends StatelessWidget {
  final AuthService auth;

  const _HomeTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Welcome Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blueAccent.withOpacity(0.1),
          child: Text(
            'Welcome, ${auth.currentUser?.fullName ?? 'Resident'} 👋',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),


        // Notices
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DBService.noticesStream(),

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No notices available'));
              }

              final notices = snapshot.data!;
              return ListView.builder(
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  return NoticeCard(notice: notices[index]); // ✅ Use custom card
                },
              );
            },
          ),
        ),

        /*Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DBService.noticesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No notices available'));
              }

              final notices = snapshot.data!;
              return ListView.builder(
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  final n = notices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(n['title'] ?? 'No Title'),
                      subtitle: Text(n['body'] ?? ''),
                      leading: const Icon(Icons.message_rounded,
                          color: Colors.indigoAccent),
                    ),
                  );
                },
              );
            },
          ),
        ),*/
      ],
    );
  }
}*/
