import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme.dart';

/// اختبار الاتصال بـ Firebase — يكتب في collection: connection_test
Future<void> checkConnection() async {
  try {
    await FirebaseFirestore.instance.collection('connection_test').add({
      'status': 'connected',
      'time': FieldValue.serverTimestamp(),
    });
    print('🔥 Firebase Connected Successfully!');
  } catch (e) {
    print('❌ Connection Failed:');
    print(e);
  }
}

/// Example screen: add users to Firestore and read them with StreamBuilder.
class FirestoreExampleScreen extends StatefulWidget {
  const FirestoreExampleScreen({super.key});

  @override
  State<FirestoreExampleScreen> createState() => _FirestoreExampleScreenState();
}

class _FirestoreExampleScreenState extends State<FirestoreExampleScreen> {
  @override
  void initState() {
    super.initState();
    checkConnection();
  }

  static Future<void> addUser() async {
    await FirebaseFirestore.instance.collection('users').add({
      'name': 'John',
      'age': 22,
      'email': 'john@email.com',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Text('Firestore Example'),
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.darkText,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await addUser();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User added to Firestore 🚀'),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppTheme.errorRed,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add user (John)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Users in Firestore',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users yet. Tap "Add user" above.',
                      style: TextStyle(color: AppTheme.mediumGray),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          data['name']?.toString() ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        subtitle: Text(
                          data['email']?.toString() ?? '—',
                          style: const TextStyle(
                            color: AppTheme.mediumGray,
                          ),
                        ),
                        trailing: Text(
                          '${data['age'] ?? '—'}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
