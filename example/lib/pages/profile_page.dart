import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:smart_query/smart_query.dart';

/// Profile model.
class UserProfile {
  const UserProfile(
      {required this.id, required this.name, required this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Handling dummyjson.com's firstName/lastName structure
    final firstName = json['firstName'] as String? ?? 'User';
    final lastName = json['lastName'] as String? ?? '';
    final name = '$firstName $lastName'.trim();

    return UserProfile(
      id: json['id'] as int,
      name: name,
      email: json['email'] as String,
    );
  }

  final int id;
  final String name;
  final String email;

  UserProfile copyWith({String? name, String? email}) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}

/// Profile Page — Mutation + Optimistic Update:
/// - Fetch user profile via QueryBuilder
/// - Edit name with TextField
/// - Save triggers mutation with optimistic update
/// - On simulated error: rollback with SnackBar
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _userId = 1;
  static const _queryKey = ['user', _userId];

  static final _dio = Dio(BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  static Future<UserProfile> _fetchProfile() async {
    final response = await _dio.get(
      'https://dummyjson.com/users/$_userId',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile');
    }
    return UserProfile.fromJson(response.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: QueryBuilder<UserProfile>(
        queryKey: _queryKey,
        fetcher: _fetchProfile,
        staleTime: const Duration(minutes: 5),
        builder: (context, result) {
          if (result.isError && result.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${result.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: result.refetch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (result.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return _ProfileContent(profile: result.data!);
        },
      ),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  const _ProfileContent({required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
  }

  @override
  void didUpdateWidget(_ProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.name != widget.profile.name) {
      _nameController.text = widget.profile.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              widget.profile.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 36,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Email (read-only)
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(widget.profile.email),
            ),
          ),
          const SizedBox(height: 16),

          // Editable name field
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Name',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save button with mutation
          MutationBuilder<UserProfile, String>(
            mutator: (newName) async {
              // Simulate network delay
              await Future<void>.delayed(const Duration(seconds: 1));

              // Simulate random failure (30% chance) to demonstrate rollback
              if (Random().nextDouble() < 0.3) {
                throw Exception('Server error: could not save profile');
              }

              // In real app, this would be an API call.
              // JSONPlaceholder doesn't actually save, but returns the data.
              return widget.profile.copyWith(name: newName);
            },
            onMutate: (newName) {
              // OPTIMISTIC UPDATE: immediately show the new name in UI
              final client = QueryClient.of(context);
              final previousProfile =
                  client.getQueryData<UserProfile>(ProfilePage._queryKey);
              client.setQueryData<UserProfile>(
                ProfilePage._queryKey,
                previousProfile?.copyWith(name: newName),
              );
              // Return previous data as context for rollback
              return previousProfile;
            },
            onError: (error, variables, rollbackContext) {
              // ROLLBACK: restore previous profile on error
              if (rollbackContext != null) {
                QueryClient.of(context).setQueryData<UserProfile>(
                  ProfilePage._queryKey,
                  rollbackContext as UserProfile,
                );
              }
              // Show error SnackBar
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Save failed: $error — rolled back.'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            onSuccess: (data, variables, context2) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile saved successfully!'),
                  ),
                );
              }
            },
            builder: (context, mutation) {
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: mutation.isLoading
                      ? null
                      : () => mutation.mutate(_nameController.text),
                  icon: mutation.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(mutation.isLoading ? 'Saving...' : 'Save Name'),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Tip: There\'s a 30% chance the save will fail to demonstrate '
            'optimistic update rollback.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
