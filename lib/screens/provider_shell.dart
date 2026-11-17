// Provider shell: Dashboard | Jobs | Earnings | Profile.
// One app, provider role — same Supabase backend as the website.
import 'package:flutter/material.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'job_route_screen.dart';
import 'provider_onboarding_screen.dart';
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
  late Future<ProviderWallet?> _wallet;
  late Future<List<WalletTransaction>> _transactions;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _provider = fetchMyProviderProfile();
    _jobs = fetchProviderJobs();
    _wallet = getProviderWallet();
    _transactions = listWalletTransactions(limit: 5);
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No provider profile yet. Complete your verification in the app '
                      '(CNIC, selfie, services and charges) — then your dashboard appears here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final done = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ProviderOnboardingScreen(profile: widget.profile),
                          ),
                        );
                        if (done == true && mounted) setState(_refresh);
                      },
                      icon: const Icon(Icons.verified_user),
                      label: const Text('Complete verification'),
                    ),
                  ],
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
                              'Your account is under review. You can take jobs once an admin approves your CNIC, selfie and documents.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                        if (status != 'approved')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final done = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => ProviderOnboardingScreen(profile: widget.profile),
                                  ),
                                );
                                if (done == true && mounted) setState(_refresh);
                              },
                              icon: const Icon(Icons.verified_user, size: 18),
                              label: const Text('Complete / update verification'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _WalletSection(walletFuture: _wallet, transactionsFuture: _transactions),
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

// ---------------- Provider wallet (migration 005) ----------------

class _WalletSection extends StatelessWidget {
  final Future<ProviderWallet?> walletFuture;
  final Future<List<WalletTransaction>> transactionsFuture;
  const _WalletSection({required this.walletFuture, required this.transactionsFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderWallet?>(
      future: walletFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load wallet: ${snap.error}'),
            ),
          );
        }
        final wallet = snap.data;
        if (wallet == null) return const SizedBox.shrink();
        final hasDues = wallet.hasDues;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppColors.teal),
                    const SizedBox(width: 8),
                    const Text('My wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      formatRs(wallet.balance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: hasDues ? AppColors.red : AppColors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasDues
                      ? '${formatRs(wallet.dues)} dues — clear your dues to keep accepting jobs.'
                      : 'Prepaid balance. The 15% platform fee is deducted from this wallet when a job completes.',
                  style: TextStyle(color: hasDues ? AppColors.red : AppColors.inkSoft),
                ),
                const SizedBox(height: 6),
                Text(
                  'If your dues go over Rs. ${kWalletDuesLimitRs.toInt()} you cannot accept new jobs until you pay.',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'To top up: send money via JazzCash / EasyPaisa to the platform account '
                    '(JazzCash: 03078110561) and share the '
                    'transaction reference with the admin. The admin verifies it and adds '
                    'the amount to your wallet.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                FutureBuilder<List<WalletTransaction>>(
                  future: transactionsFuture,
                  builder: (context, tsnap) {
                    if (tsnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final list = tsnap.data ?? [];
                    if (list.isEmpty) {
                      return const Text('No wallet activity yet.',
                          style: TextStyle(color: AppColors.inkSoft));
                    }
                    return Column(
                      children: list
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t.kindLabel,
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(
                                            '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}'
                                            '${t.reference != null ? ' · ${t.reference}' : ''}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${t.isCredit ? '+' : ''}${formatRs(t.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: t.isCredit ? AppColors.teal : AppColors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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
      // Dues check before Accept: the server enforces this too (the
      // bookings trigger rejects the update), but checking first gives
      // the provider a clear explanation instead of an error toast.
      if (status == 'accepted') {
        final canAccept = await providerCanAcceptJobs();
        if (!canAccept) {
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Dues need clearing'),
                content: const Text(
                  'Your unpaid platform dues are over Rs. 2,000, so you cannot accept new jobs yet. '
                  'Send the payment via JazzCash / EasyPaisa and share the transaction reference with the admin — '
                  'once the admin adds it to your wallet, you can accept jobs again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
      await updateBookingStatus(widget.booking.id, status);
      // Terminal status: stop publishing my live location (best-effort,
      // never fails the status update). The route screen's dispose does
      // the same when the provider leaves it.
      if (status == 'completed' ||
          status == 'cancelled' ||
          status == 'rejected') {
        try {
          await clearMyProviderLocation();
        } catch (_) {
          // Best-effort.
        }
      }
      widget.onChanged();
      // Going on the way: nudge the provider to open the route screen
      // and turn on live location sharing.
      if (status == 'on_the_way' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Live location sharing on karne ke liye Route kholein'),
            action: SnackBarAction(
              label: 'Route kholein',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => JobRouteScreen(booking: widget.booking),
                ));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // The database trigger rejects an accept over the dues limit;
        // show that as a dues message, not a generic error.
        final msg = e.toString().contains('dues exceed')
            ? 'Your dues are over Rs. 2,000 — clear them before accepting new jobs.'
            : 'Could not update job: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
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
    // Route + live location sharing for active jobs.
    if (kActiveJobStatuses.contains(b.status)) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => JobRouteScreen(booking: b),
        )),
        icon: const Icon(Icons.route, size: 18),
        label: const Text('Route'),
      ));
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
              'To update your services, charges, bio, CNIC documents or selfie, use the verification flow in the app. '
              'Your verification status and availability are managed here.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProviderOnboardingScreen(profile: profile),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('Update verification & documents'),
              ),
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
