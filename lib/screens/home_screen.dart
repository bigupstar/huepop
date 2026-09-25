import 'package:flutter/foundation.dart';
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

  void _goPremium() => setState(() => index = 3);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DiscoverPage(appState: widget.appState, onGoPremium: _goPremium),
      _LibraryPage(appState: widget.appState, onGoPremium: _goPremium),
      _MyArtworkPage(appState: widget.appState, onGoPremium: _goPremium),
      _PremiumPage(appState: widget.appState),
      _ProfilePage(appState: widget.appState),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette), label: 'My Art'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Premium'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/brand-image.png',
              height: 54,
              width: 210,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverPage extends StatelessWidget {
  const _DiscoverPage({required this.appState, required this.onGoPremium});
  final HuePopAppState appState;
  final VoidCallback onGoPremium;

  @override
  Widget build(BuildContext context) {
    final challenge = appState.dailyChallenge;
    return Column(children: [
      const _PageHeader(title: 'Home', subtitle: 'Color. Relax. Create something brilliant.'),
      Expanded(
        child: RefreshIndicator(
          onRefresh: appState.refreshCatalog,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
          if (appState.catalogLoading)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
          else if (appState.catalogError != null)
            SliverToBoxAdapter(child: _CatalogError(appState: appState))
          else ...[
            if (challenge != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6D45D8), Color(0xFFFF4FA3)]),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('DAILY COLORING CHALLENGE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          Text(challenge.title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => _openArtwork(context, appState, challenge, onGoPremium),
                            child: const Text('Start today’s challenge'),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(borderRadius: BorderRadius.circular(18), child: _ArtworkImage(artwork: challenge, width: 150, height: 150)),
                    ]),
                  ),
                ),
              ),
            if (appState.inProgress.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _SectionTitle('Continue Coloring')),
              SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: appState.inProgress, appState: appState, onGoPremium: onGoPremium)),
            ],
            const SliverToBoxAdapter(child: _SectionTitle('Featured')),
            SliverToBoxAdapter(child: _HorizontalArtworkList(artworks: appState.artworks.take(7).toList(), appState: appState, onGoPremium: onGoPremium)),
            const SliverToBoxAdapter(child: _SectionTitle('New & Popular')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250, childAspectRatio: .82, crossAxisSpacing: 14, mainAxisSpacing: 14),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ArtworkCard(artwork: appState.artworks[i], appState: appState, onGoPremium: onGoPremium),
                  childCount: appState.artworks.length,
                ),
              ),
            ),
          ],
            ],
          ),
        ),
      ),
    ]);
  }
}

class _LibraryPage extends StatefulWidget {
  const _LibraryPage({required this.appState, required this.onGoPremium});
  final HuePopAppState appState;
  final VoidCallback onGoPremium;

  @override
  State<_LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<_LibraryPage> {
  String search = '';
  String category = 'All';
  String ageGroup = 'All';

  @override
  Widget build(BuildContext context) {
    final artworks = widget.appState.artworks;
    final categories = <String>{'All', ...artworks.map((e) => e.category)}.toList();
    final filtered = artworks.where((artwork) {
      final q = search.trim().toLowerCase();
      final matchesSearch = q.isEmpty || artwork.title.toLowerCase().contains(q) || artwork.category.toLowerCase().contains(q);
      final matchesCategory = category == 'All' || artwork.category == category;
      final matchesAge = ageGroup == 'All' || artwork.ageGroup == ageGroup;
      return matchesSearch && matchesCategory && matchesAge;
    }).toList();

    return Column(children: [
      const _PageHeader(title: 'Library', subtitle: 'Find your next page to color.'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search artwork, categories…'),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: ['All', 'Kids', 'Teens', 'Adults'].map((age) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(age == 'All' ? 'All Ages' : age),
              selected: ageGroup == age,
              onSelected: (_) => setState(() => ageGroup = age),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: categories.map((item) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(item), selected: category == item, onSelected: (_) => setState(() => category = item)),
          )).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: widget.appState.catalogLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.appState.catalogError != null
                ? _CatalogError(appState: widget.appState)
                : filtered.isEmpty
                    ? const Center(child: Text('No artwork matches these filters.'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, childAspectRatio: .82, crossAxisSpacing: 14, mainAxisSpacing: 14),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _ArtworkCard(artwork: filtered[i], appState: widget.appState, onGoPremium: widget.onGoPremium),
                      ),
      ),
    ]);
  }
}

class _MyArtworkPage extends StatelessWidget {
  const _MyArtworkPage({required this.appState, required this.onGoPremium});
  final HuePopAppState appState;
  final VoidCallback onGoPremium;

  @override
  Widget build(BuildContext context) {
    final favorites = appState.artworks.where((a) => appState.favorites.contains(a.id)).toList();
    return Column(children: [
      const _PageHeader(title: 'My Art', subtitle: 'Your coloring progress, finished pieces, and favorites.'),
      Expanded(child: CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: _SectionTitle('In Progress')),
      SliverToBoxAdapter(child: appState.inProgress.isEmpty ? const _EmptyStrip('Start coloring something and it will appear here.') : _HorizontalArtworkList(artworks: appState.inProgress, appState: appState, onGoPremium: onGoPremium)),
      const SliverToBoxAdapter(child: _SectionTitle('Completed')),
      SliverToBoxAdapter(child: appState.completed.isEmpty ? const _EmptyStrip('Completed artwork will appear here.') : _HorizontalArtworkList(artworks: appState.completed, appState: appState, onGoPremium: onGoPremium)),
      const SliverToBoxAdapter(child: _SectionTitle('Favorites')),
      SliverToBoxAdapter(child: favorites.isEmpty ? const _EmptyStrip('Favorite artwork from the library to keep it here.') : _HorizontalArtworkList(artworks: favorites, appState: appState, onGoPremium: onGoPremium)),
      const SliverToBoxAdapter(child: SizedBox(height: 30)),
    ])),
    ]);
  }
}

class _PremiumPage extends StatelessWidget {
  const _PremiumPage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    final premiumArt = appState.artworks.where((a) => a.isPremium).toList();
    return Column(children: [
      const _PageHeader(title: 'Premium', subtitle: 'One purchase. Lifetime access. Every current and future premium addition.'),
      Expanded(child: ListView(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6D45D8), Color(0xFFFF4FA3)]),
            borderRadius: BorderRadius.circular(26),
          ),
          child: appState.premiumUnlocked
              ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 42),
                  SizedBox(height: 10),
                  Text('Lifetime Premium is active', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('You have lifetime access to all premium artwork, Glitter, Stickers, and every future HuePop premium addition. No additional premium purchase is required.', style: TextStyle(color: Colors.white, height: 1.45)),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('HuePop Lifetime Premium', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  const Text('A single non-consumable purchase unlocks all premium artwork plus premium creative tools, including Glitter and Stickers. Any premium content added later is included for life.', style: TextStyle(color: Colors.white, height: 1.45)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 10, children: const [
                    _PremiumBenefit(icon: Icons.image_outlined, label: 'All premium artwork'),
                    _PremiumBenefit(icon: Icons.auto_awesome, label: 'Glitter'),
                    _PremiumBenefit(icon: Icons.emoji_emotions_outlined, label: 'Stickers'),
                    _PremiumBenefit(icon: Icons.all_inclusive, label: 'Future premium additions'),
                  ]),
                  const SizedBox(height: 18),
                  FilledButton.tonalIcon(
                    onPressed: appState.purchasePending ? null : appState.buyLifetimePremium,
                    icon: appState.purchasePending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.workspace_premium),
                    label: Text('Unlock Lifetime Premium • ${appState.premiumPrice}'),
                  ),
                  TextButton(onPressed: appState.restorePremium, child: const Text('Restore previous purchase', style: TextStyle(color: Colors.white))),
                  if (appState.storeMessage != null)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(appState.storeMessage!, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  if (kDebugMode) ...[
                    const Divider(color: Colors.white24, height: 28),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: appState.premiumUnlocked,
                      onChanged: appState.setDeveloperPremiumPreview,
                      title: const Text('Developer premium preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Debug builds only. This does not create a store purchase.', style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ]),
        ),
      ),
      const _SectionTitle('Premium Artwork'),
      if (premiumArt.isEmpty)
        const _EmptyStrip('Premium artwork from artworks.json will appear here.')
      else
        _HorizontalArtworkList(artworks: premiumArt, appState: appState, onGoPremium: () {}),
      const SizedBox(height: 28),
    ])),
    ]);
  }
}

class _PremiumBenefit extends StatelessWidget {
  const _PremiumBenefit({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
      );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const _PageHeader(title: 'Profile', subtitle: 'Your HuePop settings and app information.'),
      Expanded(child: ListView(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.workspace_premium), title: const Text('Premium status'), trailing: Text(appState.premiumUnlocked ? 'Lifetime Premium' : 'Free')),
            ListTile(leading: const Icon(Icons.cloud_outlined), title: const Text('Artwork catalog'), subtitle: Text(HuePopConfig.artworkManifestUrl)),
            ListTile(leading: const Icon(Icons.refresh), title: const Text('Refresh artwork library'), onTap: appState.refreshCatalog),
            ListTile(leading: const Icon(Icons.restore), title: const Text('Restore purchases'), onTap: appState.restorePremium),
          ]),
        ),
      ),
      const SizedBox(height: 20),
    ])),
    ]);
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.appState});
  final HuePopAppState appState;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.black45),
          const SizedBox(height: 10),
          const Text('Could not load the HuePop artwork catalog.', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(appState.catalogError ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: appState.refreshCatalog, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      );
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Text(text, style: const TextStyle(color: Colors.black54)),
        ),
      );
}

class _HorizontalArtworkList extends StatelessWidget {
  const _HorizontalArtworkList({required this.artworks, required this.appState, required this.onGoPremium});
  final List<Artwork> artworks;
  final HuePopAppState appState;
  final VoidCallback onGoPremium;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 282,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: artworks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) => SizedBox(width: 200, child: _ArtworkCard(artwork: artworks[i], appState: appState, onGoPremium: onGoPremium)),
        ),
      );
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.artwork, required this.appState, required this.onGoPremium});
  final Artwork artwork;
  final HuePopAppState appState;
  final VoidCallback onGoPremium;

  @override
  Widget build(BuildContext context) {
    final locked = artwork.isPremium && !appState.premiumUnlocked;
    final progress = appState.progressFor(artwork.progressId);
    return Card(
      child: InkWell(
        onTap: () => _openArtwork(context, appState, artwork, onGoPremium),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Container(color: Colors.white, child: _ArtworkImage(artwork: artwork)),
              Positioned(
                left: 10,
                top: 10,
                child: Wrap(spacing: 5, children: [
                  if (artwork.isNew) const _Badge(text: 'NEW', color: huePopPink),
                  _Badge(text: artwork.isPremium ? 'PREMIUM' : 'FREE', color: artwork.isPremium ? huePopPurple : huePopTeal),
                ]),
              ),
              if (progress > 0)
                Positioned(right: 10, bottom: 10, child: _Badge(text: '${(progress * 100).round()}%', color: Colors.black87)),
              if (locked)
                Container(
                  color: Colors.black.withValues(alpha: .15),
                  alignment: Alignment.center,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: Color(0xFFE6DAFF), shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: huePopPurple),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(artwork.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text('${artwork.category} • ${artwork.ageGroup}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ]),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.artwork, this.width, this.height});
  final Artwork artwork;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => Image.network(
        artwork.imageUrl,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 42, color: Colors.black38)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}

Future<void> _openArtwork(BuildContext context, HuePopAppState appState, Artwork artwork, VoidCallback onGoPremium) async {
  if (!appState.canOpen(artwork)) {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lifetime Premium'),
        content: const Text('This artwork is part of HuePop Lifetime Premium. One purchase unlocks every premium artwork, Glitter, Stickers, and future premium additions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('See Premium • ${appState.premiumPrice}')),
        ],
      ),
    );
    if (go == true) onGoPremium();
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(artwork: artwork, appState: appState)));
}
