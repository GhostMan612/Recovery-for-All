// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import '../core/theme/app_colors.dart';

class SoberHouse {
  final String name;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String phone;
  final String targetDemographic; // "Men's", "Women's", "Maternal / Women & Children", "Co-ed"
  final String structureType;     // "Self-Governed", "Transitional House", "Supportive", "Clinical Level"
  final double latitude;
  final double longitude;
  final List<String> rules;
  final List<String> directoriesIndex; // Grounded directories like TransitionalHousing.org, etc.

  const SoberHouse({
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.phone,
    required this.targetDemographic,
    required this.structureType,
    required this.latitude,
    required this.longitude,
    required this.rules,
    required this.directoriesIndex,
  });
}

class SoberHousingLocatorScreen extends StatefulWidget {
  final Position? userPosition;

  const SoberHousingLocatorScreen({
    super.key,
    this.userPosition,
  });

  @override
  State<SoberHousingLocatorScreen> createState() => _SoberHousingLocatorScreenState();
}

class _SoberHousingLocatorScreenState extends State<SoberHousingLocatorScreen> {
  String _selectedDemographicFilter = 'All';
  String _selectedStructureFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Authoritative Sober Housing listings parsed directly from historical local records
  final List<SoberHouse> _soberHousesPool = [
    const SoberHouse(
      name: 'Oxford House Douglas Street',
      address: '2615 Douglas St',
      city: 'Sioux City',
      state: 'IA',
      zip: '51104',
      phone: '800-662-4357',
      targetDemographic: "Men's",
      structureType: 'Self-Governed',
      latitude: 42.5152,
      longitude: -96.4021,
      rules: ['Complete abstinence required', 'Weekly democratic group meeting', 'Shared household expenses'],
      directoriesIndex: ['TransitionalHousing.org', 'WomenSoberHousing.com'],
    ),
    const SoberHouse(
      name: 'Oxford House 16th Street',
      address: '209 16th St',
      city: 'Sioux City',
      state: 'IA',
      zip: '51105',
      phone: '800-662-4357',
      targetDemographic: "Men's",
      structureType: 'Self-Governed',
      latitude: 42.5029,
      longitude: -96.3981,
      rules: ['Democratic self-governance', 'Zero-tolerance policy', 'Shared financial rent dues'],
      directoriesIndex: ['TransitionalHousing.org', 'Recovery.org'],
    ),
    const SoberHouse(
      name: 'Jackson Recovery Center / Chad House',
      address: '2325 Douglas St',
      city: 'Sioux City',
      state: 'IA',
      zip: '51104',
      phone: '712-256-6194',
      targetDemographic: "Men's",
      structureType: 'Transitional House',
      latitude: 42.5113,
      longitude: -96.4018,
      rules: ['Curfew coordination', 'Random toxicology screenings', 'Mandatory 12-Step or SMART session logs'],
      directoriesIndex: ['AllTreatment.com', 'Drug-rehabs.org'],
    ),
    const SoberHouse(
      name: 'Jackson Recovery Center / Grandview House',
      address: '1800 Grandview St',
      city: 'Sioux City',
      state: 'IA',
      zip: '51104',
      phone: '712-256-6194',
      targetDemographic: "Men's",
      structureType: 'Transitional House',
      latitude: 42.5057,
      longitude: -96.4112,
      rules: ['Peer accountability contracts', 'Daily chore assignments', 'Weekly case manager checks'],
      directoriesIndex: ['TransitionalHousing.org', 'Recovery.org'],
    ),
    const SoberHouse(
      name: 'Jackson Recovery Center / Women & Children\'s',
      address: '3200 West 4th St',
      city: 'Sioux City',
      state: 'IA',
      zip: '51103',
      phone: '712-256-6194',
      targetDemographic: 'Maternal / Women & Children',
      structureType: 'Clinical Level',
      latitude: 42.5002,
      longitude: -96.4491,
      rules: ['Childcare integration guidelines', 'Relapse prevention classes', 'Active parenting therapy circles'],
      directoriesIndex: ['WomenSoberHousing.com', 'AllTreatment.com'],
    ),
    const SoberHouse(
      name: 'Beyond Brink Recovery Housing',
      address: 'Mankato Office Regional',
      city: 'Mankato',
      state: 'MN',
      zip: '56001',
      phone: '507-779-7080',
      targetDemographic: 'Co-ed',
      structureType: 'Transitional House',
      latitude: 44.1636,
      longitude: -93.9994,
      rules: ['Active peer recovery specialist pairing', 'Community action service pledges', 'Harm reduction guidelines'],
      directoriesIndex: ['TransitionalHousing.org', 'Addicted.org'],
    ),
    const SoberHouse(
      name: 'Simpson Housing Services',
      address: '2100 Pillsbury Ave',
      city: 'Minneapolis',
      state: 'MN',
      zip: '55404',
      phone: '612-874-8683',
      targetDemographic: 'Co-ed',
      structureType: 'Supportive',
      latitude: 44.9621,
      longitude: -93.2798,
      rules: ['Individual stability plans', 'Housing-first supportive coordination', 'Case management alignment'],
      directoriesIndex: ['TransitionalHousing.org', 'Homeless Shelter Directory'],
    ),
    const SoberHouse(
      name: 'Clare Housing',
      address: '929 Central Ave NE',
      city: 'Minneapolis',
      state: 'MN',
      zip: '55413',
      phone: '612-235-4001',
      targetDemographic: 'Co-ed',
      structureType: 'Supportive',
      latitude: 44.9922,
      longitude: -93.2471,
      rules: ['Abstinence-supportive ecosystem', 'Medication management guidance', 'Supportive independent living'],
      directoriesIndex: ['Homeless Shelter Directory', 'Recovery.org'],
    ),
  ];

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 0.621371; // Diameter of Earth in km * miles conversion
  }

  List<SoberHouse> _getProcessedHouses() {
    List<SoberHouse> houses = List.from(_soberHousesPool);

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      houses = houses.where((house) {
        return house.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            house.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            house.city.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply Demographic Filter
    if (_selectedDemographicFilter != 'All') {
      houses = houses.where((house) => house.targetDemographic == _selectedDemographicFilter).toList();
    }

    // Apply Structure Filter
    if (_selectedStructureFilter != 'All') {
      houses = houses.where((house) => house.structureType == _selectedStructureFilter).toList();
    }

    // Sort by Proximity if Location Available
    if (widget.userPosition != null) {
      houses.sort((a, b) {
        final double distA = _calculateDistance(
          widget.userPosition!.latitude,
          widget.userPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final double distB = _calculateDistance(
          widget.userPosition!.latitude,
          widget.userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
    }

    return houses;
  }

  @override
  Widget build(BuildContext context) {
    final processedList = _getProcessedHouses();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Recovery & Sober Housing', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter Block
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search houses by name or city...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
          
          // Filters Horizontal Scroll Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterDropdown(
                  label: 'Demographic',
                  currentValue: _selectedDemographicFilter,
                  options: ['All', "Men's", "Women's", 'Maternal / Women & Children', 'Co-ed'],
                  onChanged: (val) => setState(() => _selectedDemographicFilter = val!),
                ),
                const SizedBox(width: 12),
                _buildFilterDropdown(
                  label: 'Structure',
                  currentValue: _selectedStructureFilter,
                  options: ['All', 'Self-Governed', 'Transitional House', 'Supportive', 'Clinical Level'],
                  onChanged: (val) => setState(() => _selectedStructureFilter = val!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Output Count Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${processedList.length} housing locations found',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                if (widget.userPosition != null)
                  Row(
                    children: [
                      Icon(Icons.my_location, color: Theme.of(context).colorScheme.tertiary, size: 14),
                      SizedBox(width: 6),
                      Text('Sorted by distance', style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // List View Builder
          Expanded(
            child: processedList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: processedList.length,
                    itemBuilder: (context, index) {
                      final house = processedList[index];
                      double? calculatedDistance;
                      if (widget.userPosition != null) {
                        calculatedDistance = _calculateDistance(
                          widget.userPosition!.latitude,
                          widget.userPosition!.longitude,
                          house.latitude,
                          house.longitude,
                        );
                      }
                      return _buildHouseCard(house, calculatedDistance);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, color: Theme.of(context).colorScheme.outline, size: 64),
          const SizedBox(height: 16),
          Text('No housing options match your filters.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDemographicFilter = 'All';
                _selectedStructureFilter = 'All';
                _searchQuery = '';
                _searchController.clear();
              });
            },
            child: Text('Reset All Filters', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseCard(SoberHouse house, double? distance) {
    Color labelColor;
    switch (house.targetDemographic) {
      case "Men's":
        labelColor = Theme.of(context).colorScheme.primary;
        break;
      case "Women's":
        labelColor = AppColors.pink;
        break;
      case "Maternal / Women & Children":
        labelColor = AppColors.housingMaternal;
        break;
      default:
        labelColor = AppColors.housingDefault;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      house.name,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${house.address}, ${house.city}, ${house.state} ${house.zip}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (distance != null)
                Text(
                  '${distance.toStringAsFixed(1)} mi',
                  style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: labelColor, width: 1),
                ),
                child: Text(
                  house.targetDemographic,
                  style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  house.structureType,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Primary Guidelines:', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...house.rules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.tertiary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Call house trigger
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: const Text('Contact House', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Map directions trigger
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text('Directions', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Directories:', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 11)),
              ...house.directoriesIndex.map((dir) => Text(
                    dir,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontStyle: FontStyle.italic),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
