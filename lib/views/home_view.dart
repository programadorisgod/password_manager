import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../controllers/auth_controller.dart';
import '../controllers/credential_controller.dart';
import '../models/credential.dart';
import '../views/credential_detail_view.dart';
import '../views/login_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final credentialController = Get.find<CredentialController>();
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Password Manager',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'export':
                  _showExportDialog();
                  break;
                case 'import':
                  _showImportDialog();
                  break;
                case 'signout':
                  try {
                    await authController.signOut();
                    Get.offAll(() => LoginView());
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to sign out',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Text('Export Passwords'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Import Passwords'),
              ),
              PopupMenuItem(
                value: 'signout',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (credentialController.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        if (credentialController.credentials.isEmpty) {
          return Center(
            child: Text(
              'No passwords saved yet',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          itemCount: credentialController.credentials.length,
          itemBuilder: (context, index) {
            final credential = credentialController.credentials[index];
            return Card(
              color: Colors.grey[900],
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  credential.name,
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  credential.description ?? '',
                  style: TextStyle(color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.blue),
                      onPressed: () async {
                        final password = await credentialController.getDecryptedPassword(credential);
                        if (password != null) {
                          await Clipboard.setData(ClipboardData(text: password));
                          Get.snackbar(
                            'Success',
                            'Password copied to clipboard',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _showEditDialog(credential),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteDialog(credential),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final descriptionController = TextEditingController();
    final credentialController = Get.find<CredentialController>();

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Add Password',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: TextStyle(color: Colors.white),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final success = await credentialController.addCredential(
                  nameController.text,
                  passwordController.text,
                  descriptionController.text,
                );
                if (success) {
                  Get.back();
                  Get.snackbar(
                    'Success',
                    'Password added successfully',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    'Failed to add password',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to add password: ${e.toString().replaceAll('Exception: ', '')}',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Credential credential) {
    final nameController = TextEditingController(text: credential.name);
    final passwordController = TextEditingController();
    final descriptionController = TextEditingController(text: credential.description);
    final credentialController = Get.find<CredentialController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Edit Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'New Password (leave empty to keep current)',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await credentialController.updateCredential(
                credential.id!,
                nameController.text,
                passwordController.text.isEmpty ? null : passwordController.text,
                descriptionController.text,
              );
              if (success) {
                Get.back();
                Get.snackbar(
                  'Success',
                  'Password updated successfully',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  'Error',
                  'Failed to update password',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Credential credential) {
    final credentialController = Get.find<CredentialController>();
    
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Delete Password',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this password?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await credentialController.deleteCredential(credential.id!);
                Get.snackbar(
                  'Success',
                  'Password deleted successfully',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to delete password',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    final passwordController = TextEditingController();
    final credentialController = Get.find<CredentialController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Export Passwords'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your master password to export your passwords',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Master Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final exportData = await credentialController.exportCredentials(
                  passwordController.text,
                );
                
                // Convert to pretty JSON string
                final jsonString = JsonEncoder.withIndent('  ').convert(exportData);
                
                // Show the data before copying
                Get.dialog(
                  AlertDialog(
                    title: const Text('Exported Data'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Your passwords have been exported. Copy the data below:',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              jsonString,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );

                await Clipboard.setData(
                  ClipboardData(text: jsonString),
                );
                Get.snackbar(
                  'Success',
                  'Passwords exported and copied to clipboard',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to export passwords: ${e.toString().replaceAll('Exception: ', '')}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final passwordController = TextEditingController();
    final dataController = TextEditingController();
    final credentialController = Get.find<CredentialController>();

    Get.dialog(
      AlertDialog(
        title: const Text('Import Passwords'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste your exported passwords and enter your master password',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dataController,
                decoration: const InputDecoration(
                  labelText: 'Exported Data',
                  hintText: 'Paste the complete exported data here...',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Master Password',
                  hintText: 'Enter the same password used for export',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (dataController.text.isEmpty) {
                  throw Exception('Please paste the exported data');
                }
                if (passwordController.text.isEmpty) {
                  throw Exception('Please enter your master password');
                }

                // Show loading dialog
                Get.dialog(
                  const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Importing passwords...'),
                      ],
                    ),
                  ),
                );

                final success = await credentialController.importCredentials(
                  dataController.text,
                  passwordController.text,
                );
                
                Get.back(); // Close loading dialog
                
                if (success) {
                  Get.back(); // Close import dialog
                  Get.snackbar(
                    'Success',
                    'Passwords imported successfully',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                }
              } catch (e) {
                Get.back(); // Close loading dialog
                Get.snackbar(
                  'Error',
                  'Failed to import passwords: ${e.toString().replaceAll('Exception: ', '')}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
} 