import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notice_page.dart';
import 'profile_page.dart';
import '../../services/logout_helper.dart';
import 'package:lottie/lottie.dart';
import '../resident/resident_chat_page.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
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

  /*final _pages = const [
    AdminHomePage(),
    NoticePage(),

    AdminProfilePage(),
  ];*/

  @override
  Widget build(BuildContext context) {
    if (resident == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final List<Widget> pages = [
      const AdminHomePage(),
      const NoticePage(),

      ResidentChatPage(resident: resident!),
      const AdminProfilePage(),
    ];

    return Scaffold(
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
                      ? Lottie.asset('assets/lottie/Home Icon.json', height: 36)
                      : const Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: _selectedIndex == 1
                      ? Lottie.asset('assets/lottie/Bills icon animation.json', height: 33 )
                      : const Icon(Icons.announcement_outlined),
                  label: 'Notice',
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


class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await supabase.from('users').select().order('created_at', ascending: false);
      setState(() {
        users = List<Map<String, dynamic>>.from(res);
        loading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // light gray background
        foregroundColor: Colors.white, // deep blue text/icons
        elevation: 0, // flat look
        centerTitle: true, // ✅ centers the title text
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text('No users registered'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        itemBuilder: (context, i) {
          final u = users[i];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(u['full_name'] ?? ''),
              subtitle: Text('${u['email'] ?? ''}\nPhone no: ${u['phone'] ?? ''}\nRole: ${u['role'] ?? ''}'),
              trailing: Text('${u['block'] != null ? 'Block ${u['block']}' : ''}\nFlat: ${u['flat'] ?? ''}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}




/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/logout_helper.dart';
import '../../services/db_service.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: ()=>LogoutHelper.logout(context))]),
      body: Column(children: [
        ListTile(title: Text('Admin: ${auth.currentUser?.fullName ?? ''}')),
        Expanded(child: StreamBuilder<List<Map<String,dynamic>>>(
          stream: DBService.noticesStream(),
          builder: (c,s){ if (!s.hasData) return const Center(child:CircularProgressIndicator());
          final list = s.data!;
          return ListView.builder(itemCount: list.length, itemBuilder: (ctx,i){
            final n = list[i];
            return Card(child: ListTile(title: Text(n['title'] ?? ''), subtitle: Text(n['body'] ?? '')));
          });
          },
        )),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: ()=> showDialog(context: context, builder: (ctx){
          final titleCtl = TextEditingController();
          final bodyCtl = TextEditingController();
          String target = 'all';
          return AlertDialog(
            title: const Text('Create Notice'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtl, decoration: const InputDecoration(labelText:'Title')),
              TextField(controller: bodyCtl, decoration: const InputDecoration(labelText:'Body')),
              DropdownButton<String>(value: target, items: const [
                DropdownMenuItem(value:'all', child: Text('All')),
                DropdownMenuItem(value:'guards', child: Text('Guards')),
                DropdownMenuItem(value:'residents', child: Text('Residents')),
              ], onChanged: (v)=> target = v ?? 'all'),
            ]),
            actions: [
              TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                await supabase.from('notices').insert({
                  'title': titleCtl.text.trim(),
                  'body': bodyCtl.text.trim(),
                  'created_by': auth.currentUser?.authId,
                  'target': target
                });
                Navigator.pop(ctx);
              }, child: const Text('Post'))
            ],
          );
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}*/
