import 'package:flutter/material.dart';
//import 'package:inlet/pages/admin/profile_page.dart';
import 'guard_visitors_page.dart';
//import 'guard_messages_page.dart';
import 'guard_notices_page.dart';
import '../profile_page.dart';
import '../../services/logout_helper.dart';
import 'package:lottie/lottie.dart';
import '../resident/resident_chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuardHome extends StatefulWidget {
  const GuardHome({super.key});
  @override State<GuardHome> createState() => _GuardHomeState();
}
class _GuardHomeState extends State<GuardHome> {
  int _selectedIndex = 0;
  Map<String, dynamic>? resident;

  @override
  void initState() {
    super.initState();
    loadResident();
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

  //final _pages = [const GuardVisitorsPage(), const GuardNoticesPage(), const ProfilePage()];

  @override Widget build(BuildContext context) {
    if (resident == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Define pages
    final List<Widget> pages = [
      const GuardVisitorsPage(),
      const GuardNoticesPage(),
      ResidentChatPage(resident: resident!),
      const ProfilePage(),
    ];
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.white, // light gray background
          foregroundColor: Colors.white, // deep blue text/icons
          elevation: 0, // flat look
          centerTitle: true, // ✅ centers the title text
          title: const Text(
            'Guard Panel',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black, // same as foreground for harmony
              letterSpacing: 0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.redAccent),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: ()=>LogoutHelper.logout(context))],
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
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              height: 65,
              destinations: [
                NavigationDestination(
                  icon: _selectedIndex == 0
                      ? Lottie.asset('assets/lottie/Users icons.json', height: 36)
                      : const Icon(Icons.people_outlined),
                  label: 'Visitors',
                ),
               /* NavigationDestination(
                  icon: _selectedIndex == 1
                      ? Lottie.asset('assets/lottie/Bills icon animation.json', height: 33 )
                      : const Icon(Icons.message_outlined),
                  label: 'Messages',
                ),*/
                NavigationDestination(
                  icon: _selectedIndex == 1
                      ? Lottie.asset('assets/lottie/Bills icon animation.json', height: 33 )
                      : const Icon(Icons.announcement_outlined),
                  label: 'Notices',
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
     /* bottomNavigationBar: BottomNavigationBar(currentIndex: _idx, onTap: (i)=> setState(()=>_idx=i), items: const [
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Visitors'),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.announcement), label: 'Notices'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ]
      ),*/

    );
  }
}
