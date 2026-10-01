import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshUsers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getUsers();
    if (!mounted) return;
    setState(() {
      _users = data;
      _isLoading = false;
    });
    _applySearch(_searchController.text);
  }

  // Search filter
  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((u) {
          final fullName = (u['FullName'] ?? '').toString().toLowerCase();
          final username = (u['Username'] ?? '').toString().toLowerCase();
          final role = (u['UserRole'] ?? '').toString().toLowerCase();
          return fullName.contains(q) || username.contains(q) || role.contains(q);
        }).toList();
      }
    });
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final fullNameController =
        TextEditingController(text: user?['FullName']?.toString() ?? '');
    final usernameController =
        TextEditingController(text: user?['Username']?.toString() ?? '');
    final passwordController =
        TextEditingController(text: user?['Password']?.toString() ?? '');
    String selectedRole = user?['UserRole']?.toString() ?? 'Cashier';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add New User' : 'Edit User'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Please enter full name'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Please enter username'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Please enter password'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'User Role',
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final Map<String, dynamic> userData = {
                    'FullName': fullNameController.text.trim(),
                    'Username': usernameController.text.trim(),
                    'Password': passwordController.text.trim(),
                    'UserRole': selectedRole,
                  };

                  try {
                    if (user == null) {
                      await DatabaseHelper.instance.insertUser(userData);
                    } else {
                      userData['UserID'] = user['UserID'];
                      await DatabaseHelper.instance.updateUser(userData);
                    }

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }

                    if (mounted) {
                      _refreshUsers();
                    }
                  } catch (e) {
                    if (mounted) {
                      // this.context = State eke context (warning fix)
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(user == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteUser(int id) async {
    await DatabaseHelper.instance.deleteUser(id);
    _refreshUsers();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search by name, username or role...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applySearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    if (_filteredUsers.isEmpty) {
      return const Center(child: Text('No results found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final String role = user['UserRole'] ?? 'Cashier';

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  role == 'Admin' ? Colors.deepPurple : Colors.blue,
              child: Icon(
                role == 'Admin' ? Icons.admin_panel_settings : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(
              user['FullName'] ?? user['Username'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Username: ${user['Username']} | Role: $role'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showUserDialog(user: user),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user['UserID']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add User'),
      ),
    );
  }
}