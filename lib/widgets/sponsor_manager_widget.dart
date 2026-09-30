// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class SponsorContact {
  final String id;
  final String name;
  final String phone;
  final String pathway; // 'AA', 'NA', 'SMART', 'Wellbriety', 'Custom'
  final String notes;

  const SponsorContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.pathway,
    required this.notes,
  });

  SponsorContact copyWith({
    String? name,
    String? phone,
    String? pathway,
    String? notes,
  }) {
    return SponsorContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      pathway: pathway ?? this.pathway,
      notes: notes ?? this.notes,
    );
  }
}

class SponsorManagerWidget extends StatefulWidget {
  final List<SponsorContact> initialContacts;
  final Function(List<SponsorContact>) onContactsChanged;
  final Function(SponsorContact) onCallInitiated;

  const SponsorManagerWidget({
    super.key,
    required this.initialContacts,
    required this.onContactsChanged,
    required this.onCallInitiated,
  });

  @override
  State<SponsorManagerWidget> createState() => _SponsorManagerWidgetState();
}

class _SponsorManagerWidgetState extends State<SponsorManagerWidget> {
  late List<SponsorContact> _contacts;
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPathway = 'AA';

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.initialContacts);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _getPathwayColor(String pathway) {
    switch (pathway.toUpperCase()) {
      case 'AA':
        return AppColors.fellowAA;
      case 'NA':
        return AppColors.fellowNA;
      case 'SMART':
        return AppColors.fellowSMART;
      case 'WELLBRIETY':
        return AppColors.fellowWellbriety;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  void _openAddContactSheet() {
    _nameController.clear();
    _phoneController.clear();
    _notesController.clear();
    _selectedPathway = 'AA';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Support Contact',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Contact Name',
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPathway,
                      dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Pathway Affiliation',
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                      ),
                      items: ['AA', 'NA', 'SMART', 'Wellbriety', 'Custom'].map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            _selectedPathway = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final newContact = SponsorContact(
                            id: UniqueKey().toString(),
                            name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            pathway: _selectedPathway,
                            notes: _notesController.text.trim(),
                          );
                          setState(() {
                            _contacts.add(newContact);
                          });
                          widget.onContactsChanged(_contacts);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save Contact',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
    widget.onContactsChanged(_contacts);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outline, color: Theme.of(context).colorScheme.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Peer Support Network',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _openAddContactSheet,
                icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                tooltip: 'Add Support Contact',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_contacts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No sponsor or support contacts saved yet.\nTap the + icon above to secure your circle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13, height: 1.4),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                final pathwayColor = _getPathwayColor(contact.pathway);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: pathwayColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  contact.name,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pathwayColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: pathwayColor, width: 0.5),
                                  ),
                                  child: Text(
                                    contact.pathway,
                                    style: TextStyle(
                                      color: pathwayColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              contact.phone,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            if (contact.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                contact.notes,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.phone_in_talk, color: Theme.of(context).colorScheme.tertiary, size: 20),
                            onPressed: () => widget.onCallInitiated(contact),
                            tooltip: 'Call ${contact.name}',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 18),
                            onPressed: () => _deleteContact(index),
                            tooltip: 'Delete ${contact.name}',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
