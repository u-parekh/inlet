import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/*class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final blockController = TextEditingController();
  final flatController = TextEditingController();

  bool _loading = true;
  Map<String, dynamic>? _adminData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _adminData = data;
          fullNameController.text = data['full_name'] ?? '';
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phone'] ?? '';
          blockController.text = data['block'] ?? '';
          flatController.text = data['flat'] ?? '';
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('users').update({
        'full_name': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'block': blockController.text.trim(),
        'flat': flatController.text.trim(),
      }).eq('auth_id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(' Profile updated successfully!'),
              backgroundColor:  Colors.green
          ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating profile: $e'), backgroundColor:  Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent.withOpacity(0.1), // light gray background
        foregroundColor: Colors.white, // deep blue text/icons
        elevation:0, // flat look
        centerTitle: true, // ✅ centers the title text
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black, // same as foreground for harmony
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/icon/icon.png', // 👈 ensure this exists
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.blueAccent,
                child: Text(
                  fullNameController.text.isNotEmpty
                      ? fullNameController.text[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField('Full Name', fullNameController),
              _buildTextField('Email', emailController),
              _buildTextField('Phone', phoneController),
              _buildTextField('Block', blockController),
              _buildTextField('Flat', flatController),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Update Profile'),

                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}*/

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final blockController = TextEditingController();
  final flatController = TextEditingController();

  bool _loading = true;
  Map<String, dynamic>? _adminData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _adminData = data;
          fullNameController.text = data['full_name'] ?? '';
          emailController.text = data['email'] ?? '';
          phoneController.text = data['phone'] ?? '';
          blockController.text = data['block'] ?? '';
          flatController.text = data['flat'] ?? '';
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('users').update({
        'full_name': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'block': blockController.text.trim(),
        'flat': flatController.text.trim(),
      }).eq('auth_id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ prevents keyboard overlap

      appBar: AppBar(
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
        centerTitle: true,
        elevation: 2,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 20, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
      ),

      body: SafeArea( // ✅ ensures UI stays above bottom bar
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery
                .of(context)
                .padding
                .bottom + 80, // ✅ space for button
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.blue.shade600,
                child: Text(
                  fullNameController.text.isNotEmpty
                      ? fullNameController.text[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField('Full Name', fullNameController),
              _buildTextField('Email', emailController),
              _buildTextField('Phone', phoneController),
              _buildTextField('Block', blockController),
              _buildTextField('Flat', flatController),

              const SizedBox(height: 25),

              ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Update Profile'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
/*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent.withOpacity(0.1), // light gray background
        foregroundColor: Colors.white, // deep blue text/icons
        elevation:2, // flat look
        centerTitle: true, // ✅ centers the title text
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            //fontWeight: FontWeight.bold,
            color: Colors.black, // same as foreground for harmony
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor:Colors.blue.shade600,
                child: Text(
                  fullNameController.text.isNotEmpty
                      ? fullNameController.text[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField('Full Name', fullNameController),
              _buildTextField('Email', emailController),
              _buildTextField('Phone', phoneController),
              _buildTextField('Block', blockController),
              _buildTextField('Flat', flatController),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Update Profile'),

                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}*/

/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/logout_helper.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final u = auth.currentUser;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: Padding(padding: const EdgeInsets.all(12), child: Column(
      children: [
        Text('Name: ${u?.fullName ?? ''}'),
        Text('Email: ${u?.email ?? ''}'),
        Text('Phone: ${u?.phone ?? ''}'),
        Text('Block: ${u?.block ?? ''}'),
        Text('Flat: ${u?.flat ?? ''}'),
        const SizedBox(height:20),
        ElevatedButton(onPressed: ()=> LogoutHelper.logout(context), child: const Text('Logout'))
      ],
    )));
  }
}*/
