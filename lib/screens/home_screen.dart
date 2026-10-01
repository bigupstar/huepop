import 'dart:io';

import 'package:flutter/material.dart';

import '../models/artwork.dart';
import '../services/huepop_config.dart';
import '../state/huepop_app_state.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.appState});
  final HuePopAppState appState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  static const _destinations = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Library'),
    (Icons.download_outlined, Icons.download_done_rounded, 'Downloads'),
    (Icons.palette_outlined, Icons.palette, 'My Art'),
    (Icons.workspace_premium_outlined, Icons.workspace_premium, 'Premium'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DiscoverPage(appState: widget.appState),
      _LibraryPage(appState: widget.appState),
      _DownloadsPage(appState: widget.appState),
      _MyArtworkPage(appState: widget.appState),
      _StorePage(appState: widget.appState),
      _ProfilePage(appState: widget.appState),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final tablet = constraints.maxWidth >= 720;
      if (tablet) {
        return Scaffold(
          body: SafeArea(
            child: Row(children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (value) => setState(() => index = value),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Image.asset('assets/brand-image.png', width: 68, height: 52, fit: BoxFit.contain),
                ),
                destinations: _destinations
                    .map((item) => NavigationRailDestination(
                          icon: Icon(item.$1),
                          selectedIcon: Icon(item.$2),
                          label: Text(item.$3),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: IndexedStack(index: index, children: pages)),
            ]),
          ),
        );
      }

      return Scaffold(
        body: SafeArea(child: IndexedStack(index: index, children: pages)),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: (value) => setState(() => index = value),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 9,
          iconSize: 23,
          items: _destinations
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item.$1),
                    activeIcon: Icon(item.$2),
                    label: item.$3,
                  ))
              .toList(),
        ),
      );
    });
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset('assets/brand-image.png', width: 170, height: 46, fit: BoxFit.contain, alignment: Alignment.centerLeft),
        const SizedBox(height: 6),
        if (title != 'HuePop')
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        if (title != 'HuePop') const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
      ]),
    );
  }
}

class _DiscoverPage extends StatelessWidget {
  const _DiscoverPage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    final challenge = appState.dailyChallenge;
    final continueArt = appState.inProgress;
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _PageHeader(title: 'HuePop', subtitle: 'Color. Relax. Create something brilliant.')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: challenge == null
                ? _ColorCloudStatus(appState: appState)
                : LayoutBuilder(builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('DAILY COLORING CHALLENGE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 11)),
                      const SizedBox(height: 8),
                      Text(challenge.title, style: TextStyle(color: Colors.white, fontSize: compact ? 24 : 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _openArtwork(context, appState, challenge),
                        child: const Text('Start today’s challenge'),
                      ),
                    ]);
                    final art = ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _ArtworkImage(artwork: challenge, appState: appState, width: compact ? double.infinity : 150, height: 150),
                    );
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6D45D8), Color(0xFFFF4FA3)]),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: compact
                          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 14), art])
                          : Row(children: [Expanded(child: text), const SizedBox(width: 12), art]),
                    );
                  }),
          ),
        ),
        if (continueArt.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionTitle('Continue Coloring')),
          SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: continueArt, appState: appState)),
        ],
        const SliverToBoxAdapter(child: _SectionTitle('Featured')),
        SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: appState.artworks.take(7).toList(), appState: appState)),
        const SliverToBoxAdapter(child: _SectionTitle('New & Popular')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: .78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ArtworkCard(artwork: appState.artworks[i], appState: appState),
              childCount: appState.artworks.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _LibraryPage extends StatefulWidget {
  const _LibraryPage({required this.appState});
  final HuePopAppState appState;

  @override
  State<_LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<_LibraryPage> {
  String search = '';
  String collection = 'All';

  @override
  Widget build(BuildContext context) {
    final collections = <String>{'All', ...widget.appState.artworks.map((e) => e.collection)}.toList();
    final filtered = widget.appState.artworks.where((artwork) {
      final matchesCollection = collection == 'All' || artwork.collection == collection;
      final q = search.trim().toLowerCase();
      final matchesSearch = q.isEmpty || artwork.title.toLowerCase().contains(q) || artwork.collection.toLowerCase().contains(q);
      return matchesCollection && matchesSearch;
    }).toList();

    return Column(children: [
      const _PageHeader(title: 'Library', subtitle: 'Find your next page to color — online or offline.'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search artwork, collections…'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 42,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          scrollDirection: Axis.horizontal,
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(collections[i]),
            selected: collection == collections[i],
            onSelected: (_) => setState(() => collection = collections[i]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            childAspectRatio: .78,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ArtworkCard(artwork: filtered[i], appState: widget.appState),
        ),
      ),
    ]);
  }
}

class _DownloadsPage extends StatelessWidget {
  const _DownloadsPage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    final offline = appState.offlineArtworks;
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(
        child: _PageHeader(
          title: 'Downloads',
          subtitle: 'Keep up to 5 coloring pages ready for trips and places without Wi‑Fi.',
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEDE5FF),
                    child: Icon(Icons.offline_pin_rounded, color: huePopPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${appState.offlineCount} / ${HuePopAppState.maxOfflineDownloads} pages downloaded', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('${appState.formattedOfflineStorage} stored in HuePop private app storage', style: const TextStyle(color: Colors.black54)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: appState.offlineCount / HuePopAppState.maxOfflineDownloads),
                const SizedBox(height: 10),
                const Text(
                  'Downloaded source pages stay here until you remove them. Your editable coloring progress is saved separately, so removing a download does not erase your saved project.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              ]),
            ),
          ),
        ),
      ),
      if (offline.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_download_outlined, size: 68, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No offline pages yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Premium members can tap the download button on any artwork card.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              ]),
            ),
          ),
        )
      else ...[
        const SliverToBoxAdapter(child: _SectionTitle('Available Offline')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              childAspectRatio: .78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ArtworkCard(artwork: offline[i], appState: appState, removalMode: true),
              childCount: offline.length,
            ),
          ),
        ),
      ],
    ]);
  }
}

class _MyArtworkPage extends StatelessWidget {
  const _MyArtworkPage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    final inProgress = appState.inProgress;
    final favorites = appState.artworks.where((a) => appState.favorites.contains(a.id)).toList();
    final completed = appState.completed;
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: _PageHeader(title: 'My Artwork', subtitle: 'In progress, completed and favorites.')),
      if (inProgress.isEmpty && favorites.isEmpty && completed.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Your creations will appear here after you start coloring.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.black54)),
            ),
          ),
        )
      else ...[
        if (inProgress.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionTitle('In Progress')),
          SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: inProgress, appState: appState)),
        ],
        if (completed.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionTitle('Completed')),
          SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: completed, appState: appState)),
        ],
        if (favorites.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _SectionTitle('Favorites')),
          SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: favorites, appState: appState)),
        ],
      ],
    ]);
  }
}

class _StorePage extends StatelessWidget {
  const _StorePage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: EdgeInsets.zero, children: [
      const _PageHeader(title: 'HuePop Premium', subtitle: 'Premium packs, special collections and offline coloring.'),
      Padding(
        padding: const EdgeInsets.all(18),
        child: Card(
          color: const Color(0xFF211A33),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.workspace_premium, size: 54, color: huePopGold),
              const SizedBox(height: 12),
              const Text('Unlock the full HuePop experience', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Premium unlocks premium artwork plus up to 5 offline coloring-page downloads for travel and no-data situations.', style: TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 14),
              const _PremiumFeature(icon: Icons.download_done_rounded, text: 'Keep up to 5 pages available offline'),
              const _PremiumFeature(icon: Icons.auto_awesome, text: 'Unlock Glitter brushes and Glitter fills'),
              const _PremiumFeature(icon: Icons.emoji_emotions_outlined, text: 'Unlock Stickers'),
              const _PremiumFeature(icon: Icons.auto_awesome, text: 'Open premium artwork collections'),
              const _PremiumFeature(icon: Icons.travel_explore, text: 'Color while traveling without Wi‑Fi'),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: appState.premiumUnlocked,
                onChanged: appState.setPremiumPreview,
                title: const Text('Developer premium preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: const Text('Use this during development until live Apple/Google product IDs are connected.', style: TextStyle(color: Colors.white60)),
              ),
            ]),
          ),
        ),
      ),
      const _SectionTitle('Premium Preview'),
      _HorizontalArtworkList(artworks: appState.artworks.where((a) => a.isPremium).toList(), appState: appState),
      const SizedBox(height: 24),
    ]);
  }
}

class _PremiumFeature extends StatelessWidget {
  const _PremiumFeature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: huePopGold, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ]),
      );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    final colored = appState.inProgress.length;
    final achievements = <(IconData, String, String)>[
      (Icons.celebration, 'First Pop', colored > 0 ? 'Unlocked' : 'Start your first artwork'),
      (Icons.palette, 'Color Explorer', appState.recentColors.length >= 5 ? 'Unlocked' : 'Use 5 different colors'),
      (Icons.favorite, 'Collector', appState.favorites.length >= 3 ? 'Unlocked' : 'Favorite 3 pages'),
      (Icons.auto_awesome, 'Studio Regular', colored >= 5 ? 'Unlocked' : 'Work on 5 artworks'),
    ];
    return ListView(children: [
      const _PageHeader(title: 'Profile & Settings', subtitle: 'Your HuePop creative space.'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const CircleAvatar(radius: 32, backgroundColor: Color(0xFFEDE5FF), child: Icon(Icons.palette, size: 34, color: huePopPurple)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('HuePop Artist', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                Text('$colored artwork${colored == 1 ? '' : 's'} in progress'),
                Text('${appState.offlineCount}/5 offline pages', style: const TextStyle(color: Colors.black54)),
              ])),
            ]),
          ),
        ),
      ),
      const _SectionTitle('Achievements'),
      ...achievements.map((item) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: CircleAvatar(child: Icon(item.$1)),
            title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.$3),
          )),
      const _SectionTitle('App Configuration'),
      const ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 22),
        leading: Icon(Icons.phone_iphone_rounded),
        title: Text('Responsive device support'),
        subtitle: Text('Phone-friendly layout with tablet-first navigation'),
        trailing: Chip(label: Text('Enabled')),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        leading: const Icon(Icons.cloud_sync_outlined),
        title: const Text('Artwork Refresh'),
        subtitle: const Text(HuePopConfig.colorCloudLabel),
        trailing: appState.catalogRefreshing
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_rounded),
        onTap: appState.catalogRefreshing
            ? null
            : () async {
                final ok = await appState.refreshCatalog();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Huepop Color Cloud refreshed.' : 'Could not refresh artwork. Please check your connection and try again.')),
                );
              },
      ),
      const ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 22),
        leading: Icon(Icons.info_outline),
        title: Text('HuePop 0.2.2'),
        subtitle: Text('Color Cloud + Mobile + Offline Coloring build'),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

class _ColorCloudStatus extends StatelessWidget {
  const _ColorCloudStatus({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFFEDE5FF), borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, color: huePopPurple, size: 42),
          const SizedBox(height: 10),
          const Text('Huepop Color Cloud', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(appState.catalogError == null ? 'Loading artwork…' : 'Artwork is temporarily unavailable. Pull a fresh copy from Profile > Artwork Refresh.', textAlign: TextAlign.center),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      );
}

class _HorizontalArtworkList extends StatelessWidget {
  const _HorizontalArtworkList({required this.artworks, required this.appState});
  final List<Artwork> artworks;
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return SizedBox(
      height: phone ? 250 : 270,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: artworks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: phone ? 170 : 190, child: _ArtworkCard(artwork: artworks[i], appState: appState)),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.artwork, required this.appState, this.removalMode = false});
  final Artwork artwork;
  final HuePopAppState appState;
  final bool removalMode;

  @override
  Widget build(BuildContext context) {
    final offline = appState.isOffline(artwork.id);
    final locked = artwork.isPremium && !appState.premiumUnlocked && !offline;
    final progress = appState.hasProgress(artwork.id);
    final progressValue = appState.progressFor(artwork.id);
    final completed = progressValue >= .995;

    return Card(
      child: InkWell(
        onTap: () => _openArtwork(context, appState, artwork),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Container(color: Colors.white, child: _ArtworkImage(artwork: artwork, appState: appState)),
              if (locked) Container(color: Colors.black.withValues(alpha: .18)),
              Positioned(
                top: 8,
                left: 8,
                child: Wrap(spacing: 5, runSpacing: 5, children: [
                  if (artwork.isPremium) const _Badge('PREMIUM', huePopPurple),
                  if (artwork.isNew) const _Badge('NEW', huePopPink),
                  if (!artwork.isPremium) const _Badge('FREE', huePopTeal),
                  if (offline) const _Badge('OFFLINE', Color(0xFF315B90)),
                ]),
              ),
              if (locked) const Center(child: CircleAvatar(radius: 23, child: Icon(Icons.lock))),
              if (completed)
                const Positioned(right: 8, bottom: 8, child: _Badge('COMPLETED', huePopTeal))
              else if (progress)
                Positioned(right: 8, bottom: 8, child: _Badge('${(progressValue * 100).round()}%', const Color(0xFF333333))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(artwork.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(artwork.collection, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                ]),
              ),
              if (removalMode)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove offline download',
                  onPressed: () => _confirmRemoveOffline(context, appState, artwork),
                  icon: const Icon(Icons.delete_outline, size: 21),
                )
              else
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: offline ? 'Available offline' : appState.premiumUnlocked ? 'Download for offline coloring' : 'Premium offline download',
                  onPressed: offline ? null : () => _downloadArtwork(context, appState, artwork),
                  icon: Icon(
                    offline ? Icons.download_done_rounded : appState.premiumUnlocked ? Icons.download_rounded : Icons.lock_outline_rounded,
                    size: 21,
                    color: offline ? huePopTeal : appState.premiumUnlocked ? huePopPurple : Colors.black45,
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.artwork, required this.appState, this.width, this.height});
  final Artwork artwork;
  final HuePopAppState appState;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final local = appState.offlinePathFor(artwork.id);
    if (local != null) {
      return Image.file(File(local), fit: BoxFit.contain, width: width, height: height, errorBuilder: (_, __, ___) => Image.network(artwork.imageUrl, fit: BoxFit.contain, width: width, height: height));
    }
    return Image.network(artwork.imageUrl, fit: BoxFit.contain, width: width, height: height, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.cloud_off_rounded, color: Colors.black38, size: 38)));
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .4)),
      );
}

Future<void> _downloadArtwork(BuildContext context, HuePopAppState appState, Artwork artwork) async {
  if (!appState.premiumUnlocked) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_rounded, color: huePopPurple, size: 38),
        title: const Text('Premium offline coloring'),
        content: const Text('Offline downloads are a HuePop Premium feature. Premium members can keep up to 5 coloring pages on this device for coloring without Wi‑Fi or mobile data.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }

  final result = await appState.downloadForOffline(artwork);
  if (!context.mounted) return;

  switch (result) {
    case OfflineDownloadResult.downloaded:
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${artwork.title} is ready for offline coloring.')));
      break;
    case OfflineDownloadResult.alreadyDownloaded:
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This page is already available offline.')));
      break;
    case OfflineDownloadResult.limitReached:
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.offline_pin_rounded, color: huePopPurple, size: 38),
          title: const Text('Offline Library Full'),
          content: const Text('You can keep up to 5 coloring pages available offline. Save or export any finished artwork, then remove a downloaded page from Downloads to make room for another. Your saved coloring progress is kept separately.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      break;
    case OfflineDownloadResult.premiumRequired:
      break;
    case OfflineDownloadResult.failed:
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HuePop could not save that page for offline use. Please try again.')));
      break;
  }
}

Future<void> _confirmRemoveOffline(BuildContext context, HuePopAppState appState, Artwork artwork) async {
  final hasProgress = appState.hasProgress(artwork.id);
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove offline page?'),
      content: Text(
        hasProgress
            ? 'This removes the downloaded source page from offline storage, but your saved coloring project will remain in My Art.'
            : 'This removes the downloaded source page from offline storage. You can download it again later when Premium is active.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ),
  );
  if (remove != true) return;
  await appState.removeOffline(artwork.id);
}

Future<void> _openArtwork(BuildContext context, HuePopAppState appState, Artwork artwork) async {
  if (!appState.canOpen(artwork)) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium artwork'),
        content: const Text('This page is part of HuePop Premium. Live Apple/Google purchases will be connected to the Premium entitlement. You can enable Developer premium preview from the Premium tab while building.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EditorScreen(
        artwork: artwork,
        appState: appState,
        localArtworkPath: appState.offlinePathFor(artwork.id),
      ),
    ),
  );
}
