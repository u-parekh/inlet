import 'package:flutter/material.dart';
import 'package:inlet/pages/auth/login_page.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
//import 'check_email_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<void> saveUserFcmToken() async {
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


/*Future<void> saveFcmTokenForCurrentUser() async {
  final fcm = FirebaseMessaging.instance;
  final permission = await fcm.requestPermission();
  if (permission.authorizationStatus == AuthorizationStatus.denied) return;

  final token = await fcm.getToken();
  final userId = supabase.auth.currentUser?.id;
  if (token != null && userId != null) {
    // update users table where auth_id = userId
    await supabase.from('users').update({'fcm_token': token}).eq('auth_id', userId);
  }*/

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final uid = supabase.auth.currentUser?.id;
    if (newToken != null && uid != null) {
      await supabase.from('users').update({'fcm_token': newToken}).eq('auth_id', uid);
    }
  });
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _fullName = '', _email = '', _password = '', _phone = '', _block = '', _flat = '', _role = 'Resident';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Register',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/icon/icon.png', // 👈 Ensure your icon path is valid
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: size.width < 500 ? double.infinity : 450,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                   Icon(
                    Icons.person_add_alt_1,
                    color: Colors.blue.shade600,
                    size: 60,
                  ),
                  const SizedBox(height: 12),
                   Text(
                    "Create Your Account",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Join the Inlet now!",
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // 👤 Full Name
                  TextFormField(
                    decoration: _inputDecoration("Full Name", Icons.person_outline),
                    onSaved: (v) => _fullName = v ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),

                  // 📧 Email
                  TextFormField(
                    decoration: _inputDecoration("Email", Icons.email_outlined),
                    onSaved: (v) => _email = v ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),

                  // 🔒 Password
                  TextFormField(
                    obscureText: true,
                    decoration: _inputDecoration("Password", Icons.lock_outline),
                    onSaved: (v) => _password = v ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),

                  // 📞 Phone
                  TextFormField(
                    decoration: _inputDecoration("Phone Number", Icons.phone_outlined),
                    onSaved: (v) => _phone = v ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),

                  // 🏢 Block
                  TextFormField(
                    decoration: _inputDecoration("Block Number/House Number", Icons.apartment_outlined),
                    onSaved: (v) => _block = v ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),

                  // 🏠 Flat
                  TextFormField(
                    decoration: _inputDecoration("Flat Name/Society Name", Icons.home_outlined),
                    onSaved: (v) => _flat = v ?? '',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),

                  // 👮 Role Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Resident', child: Text('Resident')),
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'Guard', child: Text('Guard')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'Resident'),
                  ),
                  const SizedBox(height: 24),

                  // 🔘 Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.person_add),
                      label: Text(
                        _loading ? 'Creating Account...' : 'Register',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: _loading
                          ? null
                          : () async {
                        if (!_formKey.currentState!.validate()) return;
                        _formKey.currentState!.save();
                        setState(() => _loading = true);
                        final err = await auth.register(
                          fullName: _fullName,
                          email: _email,
                          password: _password,
                          phone: _phone,
                          block: _block,
                          flat: _flat,
                          role: _role,
                        );
                        setState(() => _loading = false);
                        if (err != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(err),
                              backgroundColor:  Colors.red
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Your account has been successfully created."),
                              backgroundColor:  Colors.green
                            )
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                             // builder: (_) => CheckEmailPage(email: _email),
                                builder: (_) => LoginPage(),

                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  String? _required(String? v) => (v == null || v.isEmpty) ? 'Required' : null;
}

// lib/pages/register_page.dart
/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'check_email_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _fullName = '', _email = '', _password = '', _phone = '', _block = '', _flat = '', _role = 'Resident';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(decoration: const InputDecoration(labelText: 'Full Name'), onSaved: (v) => _fullName = v ?? '', validator: _required),
              TextFormField(decoration: const InputDecoration(labelText: 'Email'), onSaved: (v) => _email = v ?? '', validator: _required),
              TextFormField(obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onSaved: (v) => _password = v ?? '', validator: _required),
              TextFormField(decoration: const InputDecoration(labelText: 'Phone Number'), onSaved: (v) => _phone = v ?? '', validator: _required),
              TextFormField(decoration: const InputDecoration(labelText: 'Block Number'), onSaved: (v) => _block = v ?? '', validator: _required),
              TextFormField(decoration: const InputDecoration(labelText: 'Flat Name'), onSaved: (v) => _flat = v ?? '', validator: _required),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'Resident', child: Text('Resident')),
                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'Guard', child: Text('Guard')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'Resident'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                  if (!_formKey.currentState!.validate()) return;
                  _formKey.currentState!.save();
                  setState(() => _loading = true);
                  final err = await auth.register(
                    fullName: _fullName,
                    email: _email,
                    password: _password,
                    phone: _phone,
                    block: _block,
                    flat: _flat,
                    role: _role,
                  );
                  setState(() => _loading = false);
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  } else {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CheckEmailPage(email: _email)));
                  }
                },
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) => (v == null || v.isEmpty) ? 'Required' : null;
}*/

/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String fullName='', email='', password='', phone='', block='', flat='', role='Resident';
  bool _loading=false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen:false);
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            TextFormField(decoration: const InputDecoration(labelText: 'Full Name'), onChanged: (v)=>fullName=v),
            TextFormField(decoration: const InputDecoration(labelText: 'Email'), onChanged: (v)=>email=v),
            TextFormField(obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onChanged: (v)=>password=v),
            TextFormField(decoration: const InputDecoration(labelText: 'Phone Number'), onChanged: (v)=>phone=v),
            TextFormField(decoration: const InputDecoration(labelText: 'Block No'), onChanged: (v)=>block=v),
            TextFormField(decoration: const InputDecoration(labelText: 'Flat No'), onChanged: (v)=>flat=v),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                DropdownMenuItem(value:'Resident', child: Text('Resident')),
                DropdownMenuItem(value:'Admin', child: Text('Admin')),
                DropdownMenuItem(value:'Guard', child: Text('Guard')),
              ],
              onChanged: (v)=> role = v ?? 'Resident',
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loading ? null : () async {
              setState(()=>_loading=true);
              final err = await auth.register(
                  fullName: fullName, email:email, password:password, phone:phone, block:block, flat:flat, role:role
              );
              setState(()=>_loading=false);
              if (err != null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            }, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Register'))
          ]),
        ),
      ),
    );
  }
}*/
// lib/pages/register_page.dart
