// Provider shell: Dashboard | Jobs | Earnings | Profile.
// One app, provider role — same Supabase backend as the website.
import 'package:flutter/material.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'tracking_screen.dart';

class ProviderShell extends StatefulWidget {
  final Profile profile;
  const ProviderShell({super.key, required this.profile});
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ProviderDashboardTab(profile: widget.profile),
      const _ProviderJobsTab(),
      const ConversationsScreen(),
      const _ProviderEarningsTab(),
      _ProviderProfileTab(profile: widget.profile),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.inkSoft,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------- Dashboard ----------------

class _ProviderDashboardTab extends StatefulWidget {
  final Profile profile;
  const _ProviderDashboardTab({required this.profile});
  @override
  State<_ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<_ProviderDashboardTab> {
  late Future<Map<String, dynamic>?> _provider;
  late Future<List<Booking>> _jobs;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _provider = fetchMyProviderProfile();
    _jobs = fetchProviderJobs();
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _toggling = true);
    try {
      await setAvailability(value);
      if (mounted) setState(_refresh);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update availability: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider dashboard')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _provider,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load profile: ${snap.error}'));
          final p = snap.data;
          if (p == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No provider profile yet. Complete your registration on the website '
                  '(CNIC, services and charges) — then your dashboard appears here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final status = (p['verification_status'] as String?) ?? 'pending';
          final isAvailable = (p['is_available'] as bool?) ?? true;
          final rating = (p['average_rating'] as num?) ?? 0;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.tealLight,
                              child: Text(
                                (widget.profile.fullName ?? 'P').isNotEmpty
                                    ? (widget.profile.fullName ?? 'P')[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.profile.fullName ?? 'Provider',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('${p['experience_years'] ?? 0} yrs experience'
                                      '${p['city'] != null ? ' · ${p['city']}' : ''}'),
                                  if (rating > 0) Text('★ $rating average rating'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(
                            status == 'approved'
                                ? 'Verified'
                                : status == 'rejected'
                                    ? 'Rejected'
                                    : 'Verification pending',
                          ),
                          backgroundColor: status == 'approved'
                              ? AppColors.tealLight
                              : const Color(0xFFFFF3D6),
                        ),
                        if (status != 'approved')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Your account is under review. You can take jobs once an admin approves your CNIC and documents.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile(
                    title: const Text('Available for jobs', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isAvailable
                        ? 'You are online — customers can book you.'
                        : 'You are offline — new booking requests will not come to you.'),
                    value: isAvailable,
                    onChanged: _toggling ? null : _toggleAvailability,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Latest jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<List<Booking>>(
                  future: _jobs,
                  builder: (context, jsnap) {
                    if (jsnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final jobs = jsnap.data ?? [];
                    if (jobs.isEmpty) return const Text('No jobs yet.');
                    return Column(
                      children: jobs.take(3).map((b) => _JobTile(booking: b, onChanged: () => setState(_refresh))).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Jobs ----------------

class _ProviderJobsTab extends StatefulWidget {
  const _ProviderJobsTab();
  @override
  State<_ProviderJobsTab> createState() => _ProviderJobsTabState();
}

class _ProviderJobsTabState extends State<_ProviderJobsTab> {
  late Future<List<Booking>> _jobs;
  @override
  void initState() {
    super.initState();
    _jobs = fetchProviderJobs();
  }

  void _refresh() => setState(() => _jobs = fetchProviderJobs());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My jobs')),
      body: FutureBuilder<List<Booking>>(
        future: _jobs,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Could not load jobs: ${snap.error}'));
          final jobs = snap.data ?? [];
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs assigned yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, i) => _JobTile(booking: jobs[i], onChanged: _refresh),
            ),
          );
        },
      ),
    );
  }
}

class _JobTile extends StatefulWidget {
  final Booking booking;
  final VoidCallback onChanged;
  const _JobTile({required this.booking, required this.onChanged});
  @override
  State<_JobTile> createState() => _JobTileState();
}

class _JobTileState extends State<_JobTile> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await updateBookingStatus(widget.booking.id, status);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update job: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final actions = <Widget>[];
    if (b.status == 'pending') {
      actions.addAll([
        ElevatedButton(onPressed: _busy ? null : () => _setStatus('accepted'), child: const Text('Accept')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: _busy ? null : () => _setStatus('rejected'), child: const Text('Reject')),
      ]);
    } else if (b.status == 'accepted' || b.status == 'confirmed') {
      actions.add(ElevatedButton(
          onPressed: _busy ? null : () => _setStatus('on_the_way'), child: const Text('Start — on my way')));
    } else if (b.status == 'on_the_way') {
      actions.add(ElevatedButton(
          onPressed: _busy ? null : () => _setStatus('in_progress'), child: const Text('Work started')));
    } else if (b.status == 'in_progress') {
      actions.add(ElevatedButton(
          onPressed: _busy ? null : () => _setStatus('completed'), child: const Text('Mark completed')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Chip(label: Text(statusLabel(b.status)), backgroundColor: AppColors.tealLight),
              ],
            ),
            if (b.description != null && b.description!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(b.description!)),
            if (b.scheduledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Scheduled: ${b.scheduledAt!.day}/${b.scheduledAt!.month}/${b.scheduledAt!.year} '
                  '${b.scheduledAt!.hour}:${b.scheduledAt!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            if (b.estimatedPrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Job value: ${formatRs(b.estimatedPrice!)} · You receive ${formatRs((b.estimatedPrice! * 0.85).round())} after 15% fee'),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(children: actions),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackingScreen(booking: b),
              )),
              child: const Text('View details'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Earnings ----------------

class _ProviderEarningsTab extends StatefulWidget {
  const _ProviderEarningsTab();
  @override
  State<_ProviderEarningsTab> createState() => _ProviderEarningsTabState();
}

class _ProviderEarningsTabState extends State<_ProviderEarningsTab> {
  late Future<Map<String, num>> _earnings;
  late Future<List<Map<String, dynamic>>> _reviews;
  @override
  void initState() {
    super.initState();
    _earnings = fetchProviderEarnings();
    _reviews = fetchProviderReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, num>>(
              future: _earnings,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final e = snap.data ?? {'earned': 0, 'commission': 0, 'jobs': 0};
                final earned = e['earned'] ?? 0;
                final commission = e['commission'] ?? 0;
                final jobs = e['jobs'] ?? 0;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _statCard('Total earned', formatRs(earned))),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard('Platform fee (15%)', formatRs(commission))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _statCard('Completed jobs', '$jobs'),
                    if (jobs == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('No completed jobs yet. Your earnings will appear here once jobs are completed.',
                            style: TextStyle(color: AppColors.inkSoft)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Customer reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviews,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) return const Text('No reviews yet.');
                return Column(
                  children: list.map((r) {
                    final name = r['profiles'] is Map<String, dynamic>
                        ? (r['profiles'] as Map<String, dynamic>)['full_name'] as String? ?? 'Customer'
                        : 'Customer';
                    return Card(
                      child: ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text((r['comment'] as String?) ?? ''),
                        trailing: Text('★ ${r['rating']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.amberDark)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.teal)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Provider profile ----------------

class _ProviderProfileTab extends StatelessWidget {
  final Profile profile;
  const _ProviderProfileTab({required this.profile});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.tealLight,
                      child: Text(
                        (profile.fullName ?? 'P').isNotEmpty ? (profile.fullName ?? 'P')[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 24, color: AppColors.teal, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.fullName ?? 'Provider',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(profile.email, style: const TextStyle(color: AppColors.inkSoft)),
                          if (profile.phone != null) Text(profile.phone!, style: const TextStyle(color: AppColors.inkSoft)),
                          const Chip(label: Text('provider'), backgroundColor: AppColors.tealLight),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'To update your services, charges, bio or CNIC documents, use the provider registration on the website. '
              'Your verification status and availability are managed here.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async => db.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
