import 'package:flutter/material.dart';

import '../models/novel.dart';
import 'reader_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.favoriteNovels,
    required this.isAr,
    required this.onRemoveFavorite,
  });

  final List<Novel> favoriteNovels;
  final bool isAr;
  final Function(Novel) onRemoveFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'المفضلة' : 'Favorites'),
      ),
      body: favoriteNovels.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAr
                        ? 'لا توجد روايات مفضلة'
                        : 'No favorite novels',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: 0.62,
              ),
              itemCount: favoriteNovels.length,
              itemBuilder: (context, index) {
                final novel = favoriteNovels[index];
                return _FavoriteNovelCard(
                  novel: novel,
                  isAr: isAr,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(novel: novel),
                      ),
                    );
                  },
                  onRemove: () => onRemoveFavorite(novel),
                );
              },
            ),
    );
  }
}

class _FavoriteNovelCard extends StatelessWidget {
  const _FavoriteNovelCard({
    required this.novel,
    required this.isAr,
    required this.onTap,
    required this.onRemove,
  });

  final Novel novel;
  final bool isAr;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        novel.coverAssetPath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.book,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    novel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.favorite_rounded),
                color: Colors.red,
                onPressed: onRemove,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



