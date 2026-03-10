import 'package:a_pds/widgets/Public/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ChatPage.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final DatabaseReference db = FirebaseDatabase.instance.ref().child("users");
  final DatabaseReference contactsDb = FirebaseDatabase.instance.ref().child("user_contacts");
  List<Map> allAppUsers = [];
  List<Map> filteredUsers = [];
  List<Map> importedContacts = [];
  List<Map> mergedContacts = [];
  bool isLoading = true;
  bool isSearching = false;
  bool isImporting = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    searchController.addListener(searchUsers);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      loadAllAppUsers(), // Load all app users first
      loadImportedContacts(), // Then load imported contacts
    ]);
  }

  String _normalizePhoneNumber(String phone) {
    // Remove all non-numeric characters and leading country code if present
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // If number starts with 91 (India) and length > 10, remove the 91
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    // Take last 10 digits if number is longer
    if (cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }
    return cleaned;
  }

  Future<void> loadAllAppUsers() async {
    try {
      final snapshot = await db.get();
      final currentUser = FirebaseAuth.instance.currentUser;
      List<Map> temp = [];

      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          if (key != currentUser!.uid) {
            temp.add({
              "uid": key,
              "name": value["name"] ?? "Unknown",
              "phone": value["phone"] ?? "",
              "normalizedPhone": _normalizePhoneNumber(value["phone"] ?? ""),
              "email": value["email"] ?? "",
              "lastSeen": value["lastSeen"] ?? "",
              "isOnline": value["isOnline"] ?? false,
            });
          }
        });
      }

      setState(() {
        allAppUsers = temp;
      });

      _mergeContacts(); // Merge after loading both
    } catch (e) {
      print("Error loading users: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading users: $e")),
      );
    }
  }

  Future<void> loadImportedContacts() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await contactsDb.child(currentUser.uid).get();

      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        List<Map> temp = [];

        data.forEach((key, value) {
          temp.add({
            "id": key,
            "name": value["name"] ?? "Unknown",
            "phone": value["phone"] ?? "",
            "normalizedPhone": _normalizePhoneNumber(value["phone"] ?? ""),
            "lastSeen": value["lastSeen"] ?? "",
          });
        });

        setState(() {
          importedContacts = temp;
        });
      } else {
        setState(() {
          importedContacts = [];
        });
      }

      _mergeContacts(); // Merge after loading
    } catch (e) {
      print("Error loading imported contacts: $e");
      setState(() {
        importedContacts = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _mergeContacts() {
    Map<String, Map> mergedMap = {};

    // First, add all imported contacts (these are the only ones we want to show)
    for (var contact in importedContacts) {
      String normalizedPhone = contact["normalizedPhone"];
      if (normalizedPhone.isEmpty) continue;

      // Check if this imported contact matches any app user
      Map? matchedUser;
      for (var user in allAppUsers) {
        if (user["normalizedPhone"] == normalizedPhone) {
          matchedUser = user;
          break;
        }
      }

      if (matchedUser != null) {
        // This imported contact is also an app user
        mergedMap[normalizedPhone] = {
          "uid": matchedUser["uid"],
          "name": matchedUser["name"],
          "phone": matchedUser["phone"],
          "normalizedPhone": normalizedPhone,
          "email": matchedUser["email"],
          "lastSeen": matchedUser["lastSeen"],
          "isOnline": matchedUser["isOnline"],
          "hasAppAccount": true,
          "isBoth": true,
          "contactId": contact["id"],
        };
      } else {
        // This is just an imported contact (not an app user)
        mergedMap[normalizedPhone] = {
          "uid": null,
          "name": contact["name"],
          "phone": contact["phone"],
          "normalizedPhone": normalizedPhone,
          "email": "",
          "lastSeen": "",
          "isOnline": false,
          "hasAppAccount": false,
          "isBoth": false,
          "contactId": contact["id"],
        };
      }
    }

    // Convert map to list
    List<Map> mergedList = mergedMap.values.toList();

    // Sort by name
    mergedList.sort((a, b) => (a["name"] ?? "").compareTo(b["name"] ?? ""));

    setState(() {
      mergedContacts = mergedList;
      filteredUsers = mergedContacts;
    });
  }

  void searchUsers() {
    if (searchController.text.isEmpty) {
      setState(() {
        filteredUsers = mergedContacts;
      });
    } else {
      setState(() {
        filteredUsers = mergedContacts
            .where((user) => (user["name"] ?? "")
            .toLowerCase()
            .contains(searchController.text.toLowerCase()))
            .toList();
      });
    }
  }

  void openChat(Map user) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      bool hasAppAccount = user["hasAppAccount"] == true;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            senderId: currentUser.uid,
            senderName: currentUser.displayName ?? currentUser.email?.split('@').first ?? "User",
            receiverId: hasAppAccount ? user["uid"] : null,
            receiverName: user["name"],
            receiverPhone: user["phone"],
            receiverNormalizedPhone: user["normalizedPhone"],
            hasAppAccount: hasAppAccount,
          ),
        ),
      ).then((_) {
        // Refresh data when returning from chat
        _initializeData();
      });
    }
  }

  void navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      _initializeData();
    });
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Import Contacts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contacts, color: Colors.blue),
              ),
              title: const Text(
                'Import All Contacts',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Import all contacts from your phone'),
              onTap: () {
                Navigator.pop(context);
                _importAllPhoneContacts();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add, color: Colors.green),
              ),
              title: const Text(
                'Pick Single Contact',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Select one contact to add'),
              onTap: () {
                Navigator.pop(context);
                _pickSingleContact();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh, color: Colors.orange),
              ),
              title: const Text(
                'Refresh Contacts',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Reload contacts from Firebase'),
              onTap: () {
                Navigator.pop(context);
                _initializeData();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep, color: Colors.red),
              ),
              title: const Text(
                'Clear All Contacts',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Remove all imported contacts'),
              onTap: () {
                Navigator.pop(context);
                _clearAllImportedContacts();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importAllPhoneContacts() async {
    setState(() {
      isImporting = true;
    });

    try {
      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        if (contacts.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No contacts found on device'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          int importedCount = 0;
          final currentUser = FirebaseAuth.instance.currentUser;

          if (currentUser == null) return;

          for (var contact in contacts) {
            if (contact.phones.isNotEmpty) {
              final phoneNumber = contact.phones.first.number;
              final name = contact.displayName;

              // Check if contact already exists in imported contacts
              bool exists = importedContacts.any((c) =>
              _normalizePhoneNumber(c["phone"]) == _normalizePhoneNumber(phoneNumber));

              if (!exists) {
                final contactId = DateTime.now().millisecondsSinceEpoch.toString();

                await contactsDb
                    .child(currentUser.uid)
                    .child(contactId)
                    .set({
                  "name": name,
                  "phone": phoneNumber,
                  "importedAt": ServerValue.timestamp,
                  "lastSeen": "",
                });

                importedCount++;
              }
            }
          }

          await loadImportedContacts();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imported $importedCount new contacts'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isImporting = false;
      });
    }
  }

  Future<void> _pickSingleContact() async {
    setState(() {
      isImporting = true;
    });

    try {
      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final contact = await FlutterContacts.openExternalPick();

        if (contact != null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;

          if (contact.phones.isNotEmpty) {
            final phoneNumber = contact.phones.first.number;
            final name = contact.displayName;

            bool exists = importedContacts.any((c) =>
            _normalizePhoneNumber(c["phone"]) == _normalizePhoneNumber(phoneNumber));

            if (!exists) {
              final contactId = DateTime.now().millisecondsSinceEpoch.toString();

              await contactsDb
                  .child(currentUser.uid)
                  .child(contactId)
                  .set({
                "name": name,
                "phone": phoneNumber,
                "importedAt": ServerValue.timestamp,
                "lastSeen": "",
              });

              await loadImportedContacts();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $name'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name already exists'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Selected contact has no phone number'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isImporting = false;
      });
    }
  }

  Future<void> _clearAllImportedContacts() async {
    setState(() {
      isImporting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await contactsDb.child(currentUser.uid).remove();

      setState(() {
        importedContacts = [];
      });

      _mergeContacts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All imported contacts cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Smart Reply",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            Text(
              "Offline • Private",
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.secondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSearching ? Icons.close : Icons.search,
              color: colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: colorScheme.secondary,
            ),
            onPressed: navigateToSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSearching)
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: "Search contacts",
                  hintStyle: TextStyle(color: colorScheme.outline),
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
              ),
            ),
          Expanded(
            child: isLoading || isImporting
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isImporting ? "Importing contacts..." : "Loading...",
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ],
              ),
            )
                : filteredUsers.isEmpty
                ? emptyPage(colorScheme)
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return contactTile(user, colorScheme);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.person_add),
        label: const Text("Add Contact"),
        onPressed: _showImportOptions,
      ),
    );
  }

  Widget contactTile(Map user, ColorScheme colorScheme) {
    final hasAppAccount = user["hasAppAccount"] == true;
    final isOnline = user["isOnline"] == true;
    final lastSeen = user["lastSeen"];

    // Determine background color based on contact type
    Color avatarColor;
    Color textColor;

    if (hasAppAccount) {
      avatarColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
    } else {
      avatarColor = colorScheme.secondaryContainer;
      textColor = colorScheme.onSecondaryContainer;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: colorScheme.surface,
      child: ListTile(
        onTap: () {
          openChat(user);
        },
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: avatarColor,
              child: Text(
                (user["name"] ?? "?")[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user["name"] ?? "Unknown",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (!hasAppAccount)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Contact",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                user["phone"] ?? "",
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            if (hasAppAccount && !isOnline && lastSeen != null && lastSeen.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "Last seen: ${_formatLastSeen(lastSeen)}",
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.chat,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  String _formatLastSeen(String lastSeen) {
    try {
      final date = DateTime.parse(lastSeen);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return "Just now";
      } else if (difference.inHours < 1) {
        return "${difference.inMinutes} min ago";
      } else if (difference.inDays < 1) {
        return "${difference.inHours} hours ago";
      } else {
        return "${difference.inDays} days ago";
      }
    } catch (e) {
      return "Unknown";
    }
  }

  Widget emptyPage(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts,
            size: 80,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 20),
          Text(
            "No contacts yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Tap the + button to import contacts",
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }
}