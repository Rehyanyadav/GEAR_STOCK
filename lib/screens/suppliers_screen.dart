import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/suppliers/data/suppliers_notifier.dart';
import '../models/supplier.dart';
import '../theme/app_theme.dart';

import '../widgets/gooey_hover_button.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    final number = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/91$number?text=Hi%20$name');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final personCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Vendor / Supplier',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Company Name *',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: personCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contact Person Name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Depot / City Location',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: GooeyHoverButton(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          await ref
                              .read(suppliersProvider.notifier)
                              .addSupplier(
                                name: nameCtrl.text.trim(),
                                contactPerson: personCtrl.text.trim().isEmpty
                                    ? 'Account Manager'
                                    : personCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty
                                    ? '+91 98000 00000'
                                    : phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim().isEmpty
                                    ? 'sales@vendor.in'
                                    : emailCtrl.text.trim(),
                                city: cityCtrl.text.trim().isEmpty
                                    ? 'Pune'
                                    : cityCtrl.text.trim(),
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Supplier successfully added!'),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                            );
                          }
                        },
                        child: const Text('Add Supplier'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Supplier?'),
        content: Text(
          'Are you sure you want to remove "$name"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(suppliersProvider.notifier).deleteSupplier(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSuppliers = ref.watch(suppliersProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Suppliers & Vendors',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Add Supplier',
            onPressed: _showAddSupplierDialog,
          ),
        ],
      ),
      body: asyncSuppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Error: $e'),
              TextButton(
                onPressed: () => ref.invalidate(suppliersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allSuppliers) {
          final suppliers = allSuppliers.where((s) {
            if (_filter.isEmpty) return true;
            return s.name.toLowerCase().contains(_filter.toLowerCase()) ||
                s.contactPerson.toLowerCase().contains(_filter.toLowerCase()) ||
                s.city.toLowerCase().contains(_filter.toLowerCase());
          }).toList();

          return Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _filter = val),
                    decoration: InputDecoration(
                      hintText: 'Search vendors, contact person, city...',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              if (suppliers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No suppliers yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add your first supplier',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GooeyHoverButton(
                          child: ElevatedButton(
                            onPressed: _showAddSupplierDialog,
                            child: const Text('Add Supplier'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Suppliers List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: suppliers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final s = suppliers[index];
                      return _SupplierCard(
                        supplier: s,
                        onCall: () => _launchPhone(s.phone),
                        onWhatsApp: () => _launchWhatsApp(s.phone, s.name),
                        onDelete: () => _confirmDelete(s.id, s.name),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onCall,
    required this.onWhatsApp,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHigh.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront,
                  color: Theme.of(context).colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.contactPerson} • ${s.city}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Lead time: ~${s.leadTimeDays} days',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Remove supplier',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (s.categories.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: s.categories.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Balance Dues',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  Text(
                    '₹${s.outstandingDues.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: s.outstandingDues > 0
                          ? Theme.of(context).colorScheme.error
                          : AppStatusColors.of(context).success,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Active Orders',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  Text(
                    '${s.activeOrders} Inbound POs',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GooeyHoverButton(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GooeyHoverButton(
                  child: ElevatedButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStatusColors.of(context).success,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
