import 'package:flutter/material.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Dummy data for demonstration
  final List<Map<String, dynamic>> provincialUsers = [
    {
      'id': 1, 
      'name': 'John Provincial', 
      'email': 'john@province.com',
      'province': 'Caraga',
      'position': 'Tourism Officer',
      'submittedDate': '2025-09-01',
      'documents': ['ID Copy', 'Authorization Letter']
    },
    {
      'id': 2, 
      'name': 'Jane Provincial', 
      'email': 'jane@province.com',
      'province': 'Mindanao',
      'position': 'Regional Coordinator',
      'submittedDate': '2025-09-03',
      'documents': ['ID Copy', 'Appointment Letter']
    },
  ];

  final List<Map<String, dynamic>> municipalUsers = [
    {
      'id': 3, 
      'name': 'Mike Municipal', 
      'email': 'mike@municipal.com',
      'municipality': 'Butuan City',
      'position': 'Municipal Tourism Officer',
      'submittedDate': '2025-09-02',
      'documents': ['ID Copy', 'Mayor\'s Endorsement']
    },
  ];

  final List<Map<String, dynamic>> businessRegistrations = [
    {
      'id': 4, 
      'name': 'Caraga Adventure Tours', 
      'owner': 'Alice Johnson',
      'category': 'Tour Operator',
      'location': 'Butuan City',
      'submittedDate': '2025-08-30',
      'documents': ['Business Permit', 'DOT Accreditation', 'Insurance']
    },
    {
      'id': 5, 
      'name': 'Mindanao Beach Resort', 
      'owner': 'Bob Smith',
      'category': 'Accommodation',
      'location': 'Siargao Island',
      'submittedDate': '2025-09-04',
      'documents': ['Business Permit', 'Fire Safety Certificate', 'Sanitary Permit']
    },
  ];

  final List<Map<String, dynamic>> eventRegistrations = [
    {
      'id': 6, 
      'title': 'Butuan Heritage Festival', 
      'organizer': 'City Tourism Office',
      'category': 'Cultural Event',
      'startDate': '2025-10-15',
      'endDate': '2025-10-18',
      'location': 'Butuan City Plaza',
      'submittedDate': '2025-09-01',
      'expectedAttendees': '5000+'
    },
    {
      'id': 7, 
      'title': 'Siargao Surfing Championship', 
      'organizer': 'Philippine Surfing Association',
      'category': 'Sports Event',
      'startDate': '2025-11-20',
      'endDate': '2025-11-25',
      'location': 'Cloud 9, Siargao',
      'submittedDate': '2025-09-05',
      'expectedAttendees': '2000+'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showApprovalDialog(String type, Map<String, dynamic> item, bool isApproval) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String comment = '';
        return AlertDialog(
          title: Text(isApproval ? 'Approve $type' : 'Reject $type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item['name'] ?? item['title']}'),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => comment = value,
                decoration: InputDecoration(
                  labelText: isApproval ? 'Approval Comments (Optional)' : 'Reason for Rejection',
                  border: const OutlineInputBorder(),
                  hintText: isApproval 
                    ? 'Add any notes or conditions...' 
                    : 'Please provide reason for rejection...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processApproval(type, item, isApproval, comment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproval ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(isApproval ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
  }

  void _processApproval(String type, Map<String, dynamic> item, bool isApproval, String comment) {
    setState(() {
      switch (type) {
        case 'Provincial User':
          provincialUsers.removeWhere((user) => user['id'] == item['id']);
          break;
        case 'Municipal User':
          municipalUsers.removeWhere((user) => user['id'] == item['id']);
          break;
        case 'Business':
          businessRegistrations.removeWhere((business) => business['id'] == item['id']);
          break;
        case 'Event':
          eventRegistrations.removeWhere((event) => event['id'] == item['id']);
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['name'] ?? item['title']} has been ${isApproval ? 'approved' : 'rejected'}'),
        backgroundColor: isApproval ? Colors.green : Colors.red,
      ),
    );
  }

  void _viewDetails(Map<String, dynamic> item, String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildDetailContent(item, type),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailContent(Map<String, dynamic> item, String type) {
    switch (type) {
      case 'Provincial User':
      case 'Municipal User':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', item['name']),
            _buildDetailRow('Email', item['email']),
            _buildDetailRow('Position', item['position']),
            _buildDetailRow(type == 'Provincial User' ? 'Province' : 'Municipality', 
                           item[type == 'Provincial User' ? 'province' : 'municipality']),
            _buildDetailRow('Submitted Date', item['submittedDate']),
            const SizedBox(height: 16),
            const Text('Documents Submitted:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...((item['documents'] as List<String>).map((doc) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(doc),
                ],
              ),
            ))),
          ],
        );
      case 'Business':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Business Name', item['name']),
            _buildDetailRow('Owner', item['owner']),
            _buildDetailRow('Category', item['category']),
            _buildDetailRow('Location', item['location']),
            _buildDetailRow('Submitted Date', item['submittedDate']),
            const SizedBox(height: 16),
            const Text('Documents Submitted:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...((item['documents'] as List<String>).map((doc) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(doc),
                ],
              ),
            ))),
          ],
        );
      case 'Event':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Event Title', item['title']),
            _buildDetailRow('Organizer', item['organizer']),
            _buildDetailRow('Category', item['category']),
            _buildDetailRow('Location', item['location']),
            _buildDetailRow('Start Date', item['startDate']),
            _buildDetailRow('End Date', item['endDate']),
            _buildDetailRow('Expected Attendees', item['expectedAttendees']),
            _buildDetailRow('Submitted Date', item['submittedDate']),
          ],
        );
      default:
        return const Text('No details available');
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value ?? 'N/A')),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(String type, Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? item['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubtitle(item, type),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${item['submittedDate']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _viewDetails(item, type),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApprovalDialog(type, item, false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApprovalDialog(type, item, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSubtitle(Map<String, dynamic> item, String type) {
    switch (type) {
      case 'Provincial User':
        return '${item['position']} • ${item['province']}';
      case 'Municipal User':
        return '${item['position']} • ${item['municipality']}';
      case 'Business':
        return '${item['category']} • ${item['location']}';
      case 'Event':
        return '${item['category']} • ${item['location']}';
      default:
        return '';
    }
  }

  Widget _buildTabContent(String type, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No pending $type approvals',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All items have been reviewed',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildApprovalCard(type, items[index]);
      },
    );
  }

  int get _totalPendingCount {
    return provincialUsers.length + 
           municipalUsers.length + 
           businessRegistrations.length + 
           eventRegistrations.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Approvals'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_totalPendingCount Pending',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Provincial',
              icon: Badge(
                isLabelVisible: provincialUsers.isNotEmpty,
                label: Text('${provincialUsers.length}'),
                child: const Icon(Icons.account_balance),
              ),
            ),
            Tab(
              text: 'Municipal',
              icon: Badge(
                isLabelVisible: municipalUsers.isNotEmpty,
                label: Text('${municipalUsers.length}'),
                child: const Icon(Icons.location_city),
              ),
            ),
            Tab(
              text: 'Business',
              icon: Badge(
                isLabelVisible: businessRegistrations.isNotEmpty,
                label: Text('${businessRegistrations.length}'),
                child: const Icon(Icons.business),
              ),
            ),
            Tab(
              text: 'Events',
              icon: Badge(
                isLabelVisible: eventRegistrations.isNotEmpty,
                label: Text('${eventRegistrations.length}'),
                child: const Icon(Icons.event),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('Provincial User', provincialUsers),
          _buildTabContent('Municipal User', municipalUsers),
          _buildTabContent('Business', businessRegistrations),
          _buildTabContent('Event', eventRegistrations),
        ],
      ),
    );
  }
}