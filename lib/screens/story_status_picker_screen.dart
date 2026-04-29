import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../config/mode_config.dart';
import '../localization/app_localizations.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../theme/colors.dart';

enum StoryStatusPublishKind { story, highlight }

class StoryStatusDraft {
  final List<XFile> files;
  final String title;
  final String textColorHex;
  final double textOffsetX;
  final double textOffsetY;
  final String modeTag;
  final String locationLabel;
  final String placeId;
  final bool showModeOverlay;
  final bool showLocationOverlay;
  final StoryStatusPublishKind publishKind;
  final int durationHours;

  const StoryStatusDraft({
    required this.files,
    required this.title,
    required this.textColorHex,
    required this.textOffsetX,
    required this.textOffsetY,
    required this.modeTag,
    required this.locationLabel,
    required this.placeId,
    required this.showModeOverlay,
    required this.showLocationOverlay,
    required this.publishKind,
    required this.durationHours,
  });
}

class StoryStatusPickerScreen extends StatefulWidget {
  final String initialModeId;
  final String initialCity;
  final StoryStatusPublishKind publishKind;
  final int durationHours;

  const StoryStatusPickerScreen({
    super.key,
    this.initialModeId = ModeConfig.defaultId,
    this.initialCity = '',
    this.publishKind = StoryStatusPublishKind.story,
    this.durationHours = 24,
  });

  @override
  State<StoryStatusPickerScreen> createState() => _StoryStatusPickerScreenState();
}

class _StoryMediaSource {
  final AssetEntity? asset;
  final XFile? file;

  const _StoryMediaSource._({this.asset, this.file});

  factory _StoryMediaSource.asset(AssetEntity asset) =>
      _StoryMediaSource._(asset: asset);

  factory _StoryMediaSource.file(XFile file) => _StoryMediaSource._(file: file);

  String get id => asset?.id ?? file?.path ?? '';

  Future<XFile?> resolve() async {
    if (file != null) return file;
    final origin = await asset?.originFile;
    if (origin == null) return null;
    return XFile(origin.path, name: asset?.title ?? origin.uri.pathSegments.last);
  }
}

class _StoryStatusPickerScreenState extends State<StoryStatusPickerScreen> {
  static const _maxSelection = 10;

  final _imagePicker = ImagePicker();
  final List<_StoryMediaSource> _selectedSources = [];

  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _assets = [];
  bool _loading = true;
  bool _openingEditor = false;
  bool _hasPermission = false;
  PermissionState _permissionState = PermissionState.notDetermined;

  AppLocalizations get _l10n => context.l10n;
  bool get _isHighlightFlow => widget.publishKind == StoryStatusPublishKind.highlight;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (!permission.hasAccess) {
      setState(() {
        _loading = false;
        _hasPermission = false;
        _permissionState = permission;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    AssetPathEntity? initialAlbum;
    List<AssetEntity> initialAssets = const [];
    if (albums.isNotEmpty) {
      initialAlbum = albums.first;
      initialAssets = await initialAlbum.getAssetListPaged(page: 0, size: 120);
    }

    if (!mounted) return;
    setState(() {
      _hasPermission = true;
      _permissionState = permission;
      _albums = albums;
      _selectedAlbum = initialAlbum;
      _assets = initialAssets;
      _loading = false;
    });
  }

  Future<void> _selectAlbum(AssetPathEntity album) async {
    setState(() {
      _selectedAlbum = album;
      _loading = true;
    });
    final assets = await album.getAssetListPaged(page: 0, size: 120);
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  int _selectedIndexFor(AssetEntity asset) {
    return _selectedSources.indexWhere((source) => source.asset?.id == asset.id);
  }

  void _toggleAsset(AssetEntity asset) {
    final index = _selectedIndexFor(asset);
    setState(() {
      if (index >= 0) {
        _selectedSources.removeAt(index);
        return;
      }
      if (_selectedSources.length >= _maxSelection) {
        _showSnack(_selectionLimitLabel);
        return;
      }
      _selectedSources.add(_StoryMediaSource.asset(asset));
    });
  }

  Future<void> _openCamera() async {
    final captured = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (captured == null || !mounted) return;
    var added = false;
    setState(() {
      if (_selectedSources.length >= _maxSelection) {
        _showSnack(_selectionLimitLabel);
        return;
      }
      _selectedSources.add(_StoryMediaSource.file(captured));
      added = true;
    });
    if (added) {
      await _openEditor();
    }
  }

  Future<void> _openAlbumSheet() async {
    if (_albums.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _albumLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ..._albums.map((album) {
                final isSelected = album.id == _selectedAlbum?.id;
                return ListTile(
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _selectAlbum(album);
                  },
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.photo_library_rounded
                        : Icons.photo_album_outlined,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  title: Text(
                    album.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.74),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor() async {
    if (_openingEditor || _selectedSources.isEmpty) return;
    setState(() => _openingEditor = true);

    try {
      final files = <XFile>[];
      for (final source in _selectedSources) {
        final resolved = await source.resolve();
        if (resolved != null) {
          files.add(resolved);
        }
      }
      if (!mounted || files.isEmpty) return;

      final draft = await Navigator.of(context).push<StoryStatusDraft>(
        MaterialPageRoute(
          builder: (_) => _StoryStatusEditorScreen(
            files: files,
            initialModeId: widget.initialModeId,
            initialCity: widget.initialCity,
            publishKind: widget.publishKind,
            durationHours: widget.durationHours,
          ),
          fullscreenDialog: true,
        ),
      );

      if (draft != null && mounted) {
        Navigator.of(context).pop(draft);
      }
    } catch (e, st) {
      debugPrint('Story editor could not be opened: $e\n$st');
      if (mounted) {
        _showSnack(_editorOpenErrorLabel);
      }
    } finally {
      if (mounted) {
        setState(() => _openingEditor = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _selectedSources.isNotEmpty ? _selectedSources.last : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  _TopIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openAlbumSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedAlbum?.name ?? _galleryLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TopCountBadge(
                    label: '${_selectedSources.length}/$_maxSelection',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : !_hasPermission
                  ? _buildPermissionState()
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            onTap: preview != null ? _openEditor : null,
                            child: Container(
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                color: AppColors.bgSurface,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: preview == null
                                  ? _buildEmptyPreview()
                                  : _buildPreview(preview),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _pickerHintLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.58),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if (_selectedSources.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(_selectedSources.clear);
                                  },
                                  child: Text(
                                    _clearLabel,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: _assets.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildCameraTile();
                              }
                              final asset = _assets[index - 1];
                              final selectedIndex = _selectedIndexFor(asset);
                              return _buildAssetTile(asset, selectedIndex);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            if (_hasPermission)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.74),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedSources.isEmpty
                            ? _selectMediaLabel
                            : '${_selectedSources.length} $_selectedCountLabel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _selectedSources.isEmpty || _openingEditor
                          ? null
                          : _openEditor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _continueLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _galleryPermissionTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _galleryPermissionBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _permissionState == PermissionState.denied ||
                      _permissionState == PermissionState.restricted
                  ? PhotoManager.openSetting
                  : _loadGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _permissionState == PermissionState.denied ||
                        _permissionState == PermissionState.restricted
                    ? _openSettingsLabel
                    : _retryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.radio_button_checked_rounded,
          size: 42,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Text(
          _previewTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            _previewBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(_StoryMediaSource preview) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (preview.file != null)
            Image.file(File(preview.file!.path), fit: BoxFit.cover)
          else if (preview.asset != null)
            _AssetThumbnail(asset: preview.asset!, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _tapToEditLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _storyBuilderLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _storyBuilderBody,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraTile() {
    return GestureDetector(
      onTap: _openCamera,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.26),
              AppColors.primary.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              _cameraLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetTile(AssetEntity asset, int selectedIndex) {
    final isSelected = selectedIndex >= 0;
    return GestureDetector(
      onTap: () => _toggleAsset(asset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AssetThumbnail(asset: asset, fit: BoxFit.cover),
            if (isSelected)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary
                      : Colors.black.withValues(alpha: 0.48),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
                ),
                alignment: Alignment.center,
                child: Text(
                  isSelected ? '${selectedIndex + 1}' : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _galleryLabel => switch (_l10n.languageCode) {
        'en' => 'Gallery',
        'de' => 'Galerie',
        _ => 'Galeri',
      };

  String get _albumLabel => switch (_l10n.languageCode) {
        'en' => 'Albums',
        'de' => 'Alben',
        _ => 'Albümler',
      };

  String get _selectionLimitLabel => switch (_l10n.languageCode) {
        'en' => 'You can add up to 10 photos to one story.',
        'de' => 'Du kannst bis zu 10 Fotos zu einer Story hinzufügen.',
        _ => 'Bir duruma en fazla 10 fotoğraf ekleyebilirsin.',
      };

  String get _pickerHintLabel => switch (_l10n.languageCode) {
        'en' => 'Select multiple photos, then tap the preview to open the full-screen story editor.',
        'de' => 'Wähle mehrere Fotos aus und tippe dann auf die Vorschau, um den Story-Editor im Vollbild zu öffnen.',
        _ => 'Birden fazla fotoğraf seç, sonra tam ekran durum editörünü açmak için önizlemeye dokun.',
      };

  String get _clearLabel => switch (_l10n.languageCode) {
        'en' => 'Clear',
        'de' => 'Leeren',
        _ => 'Temizle',
      };

  String get _selectMediaLabel => switch (_l10n.languageCode) {
        'en' => 'Select media to continue',
        'de' => 'Wähle Medien aus, um fortzufahren',
        _ => 'Devam etmek için medya seç',
      };

  String get _selectedCountLabel => switch (_l10n.languageCode) {
        'en' => 'selected',
        'de' => 'ausgewählt',
        _ => 'seçildi',
      };

  String get _continueLabel => switch (_l10n.languageCode) {
        'en' => 'Continue',
        'de' => 'Weiter',
        _ => 'Devam',
      };

  String get _previewTitle => switch (_l10n.languageCode) {
        'en' => _isHighlightFlow ? 'Prepare your highlight' : 'Build your story',
        'de' => _isHighlightFlow ? 'Bereite dein Highlight vor' : 'Baue deine Story',
        _ => _isHighlightFlow ? 'Highlightını hazırla' : 'Durumunu hazırla',
      };

  String get _previewBody => switch (_l10n.languageCode) {
        'en' => _isHighlightFlow
            ? 'Choose one or more photos. In the next full-screen step you can optionally add a title, colors, mode, and location before saving the highlight.'
            : 'Choose one or more photos. In the next full-screen step you can optionally add a title, colors, mode, and location before sharing.',
        'de' => _isHighlightFlow
            ? 'Wähle ein oder mehrere Fotos aus. Im nächsten Vollbild-Schritt kannst du optional Titel, Farben, Modus und Standort ergänzen, bevor du das Highlight speicherst.'
            : 'Wähle ein oder mehrere Fotos aus. Im nächsten Vollbild-Schritt kannst du optional Titel, Farben, Modus und Standort ergänzen, bevor du die Story teilst.',
        _ => _isHighlightFlow
            ? 'Bir veya daha fazla fotoğraf seç. Sonraki tam ekran adımda istersen başlık, renk, mod ve konum ekleyip highlight olarak kaydedebilirsin.'
            : 'Bir veya daha fazla fotoğraf seç. Sonraki tam ekran adımda istersen başlık, renk, mod ve konum ekleyip durumunu paylaşabilirsin.',
      };

  String get _tapToEditLabel => switch (_l10n.languageCode) {
        'en' => 'Tap to edit full screen',
        'de' => 'Tippen, um im Vollbild zu bearbeiten',
        _ => 'Tam ekran düzenlemek için dokun',
      };

  String get _storyBuilderLabel => switch (_l10n.languageCode) {
        'en' => _isHighlightFlow ? 'Highlight editor' : 'Story composer',
        'de' => _isHighlightFlow ? 'Highlight-Editor' : 'Story-Editor',
        _ => _isHighlightFlow ? 'Highlight düzenleyici' : 'Durum düzenleyici',
      };

  String get _storyBuilderBody => switch (_l10n.languageCode) {
        'en' => _isHighlightFlow
            ? 'Keep the canvas clean or drag a title onto it, change text colors, and optionally add your mode or location before saving the highlight.'
            : 'Keep the canvas clean or drag a title onto it, change text colors, and optionally add your mode or location before sharing.',
        'de' => _isHighlightFlow
            ? 'Lass die Fläche leer oder ziehe einen Titel darauf, ändere die Textfarbe und füge vor dem Speichern des Highlights optional Modus oder Standort hinzu.'
            : 'Lass die Fläche leer oder ziehe einen Titel darauf, ändere die Textfarbe und füge vor dem Teilen optional Modus oder Standort hinzu.',
        _ => _isHighlightFlow
            ? 'Tuvali temiz bırakabilir ya da üzerine başlık sürükleyebilirsin; yazı rengini değiştirip highlightı kaydetmeden önce istersen modunu veya konumunu ekleyebilirsin.'
            : 'Tuvali temiz bırakabilir ya da üzerine başlık sürükleyebilirsin; yazı rengini değiştirip paylaşmadan önce istersen modunu veya konumunu ekleyebilirsin.',
      };

  String get _cameraLabel => switch (_l10n.languageCode) {
        'en' => 'Camera',
        'de' => 'Kamera',
        _ => 'Kamera',
      };

  String get _galleryPermissionTitle => switch (_l10n.languageCode) {
        'en' => 'Allow photo access',
        'de' => 'Erlaube den Zugriff auf Fotos',
        _ => 'Fotoğraf erişimine izin ver',
      };

  String get _galleryPermissionBody => switch (_l10n.languageCode) {
        'en' => 'PulseCity needs gallery access so you can create stories from your album.',
        'de' => 'PulseCity benötigt Zugriff auf deine Galerie, damit du Stories aus deinem Album erstellen kannst.',
        _ => 'PulseCity, albümünden durum paylaşabilmen için galeri erişimine ihtiyaç duyuyor.',
      };

  String get _retryLabel => switch (_l10n.languageCode) {
        'en' => 'Try again',
        'de' => 'Erneut versuchen',
        _ => 'Tekrar dene',
      };

  String get _openSettingsLabel => switch (_l10n.languageCode) {
        'en' => 'Open settings',
        'de' => 'Einstellungen öffnen',
        _ => 'Ayarları aç',
      };
  String get _editorOpenErrorLabel => switch (_l10n.languageCode) {
        'en' => 'The story editor could not be opened. Please try another photo.',
        'de' => 'Der Story-Editor konnte nicht geoffnet werden. Bitte versuche ein anderes Foto.',
        _ => 'Durum editoru acilamadi. Lutfen baska bir fotograf dene.',
      };
}

class _StoryStatusEditorScreen extends StatefulWidget {
  final List<XFile> files;
  final String initialModeId;
  final String initialCity;
  final StoryStatusPublishKind publishKind;
  final int durationHours;

  const _StoryStatusEditorScreen({
    required this.files,
    required this.initialModeId,
    required this.initialCity,
    required this.publishKind,
    required this.durationHours,
  });

  @override
  State<_StoryStatusEditorScreen> createState() =>
      _StoryStatusEditorScreenState();
}

class _StoryStatusEditorScreenState extends State<_StoryStatusEditorScreen> {
  static const _storyColors = <Color>[
    Colors.white,
    Color(0xFFFF4D6D),
    Color(0xFFFFD166),
    Color(0xFF7AE582),
    Color(0xFF5CC8FF),
    Color(0xFFCDB4FF),
  ];

  final _pageController = PageController();
  final _titleController = TextEditingController();
  final _imagePicker = ImagePicker();

  late final List<XFile> _files;
  int _pageIndex = 0;
  Alignment _textAlignment = const Alignment(0, 0.12);
  Color _textColor = Colors.white;
  String _modeTag = '';
  String _locationLabel = '';
  String _placeId = '';
  bool _showModeOnCanvas = false;
  bool _showLocationOnCanvas = false;
  bool _titleHovered = false;
  bool _modeHovered = false;
  bool _locationHovered = false;
  String? _selectedOverlay;

  AppLocalizations get _l10n => context.l10n;
  bool get _isHighlightFlow => widget.publishKind == StoryStatusPublishKind.highlight;

  @override
  void initState() {
    super.initState();
    _files = List<XFile>.from(widget.files);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickMode() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final allModes = <String>['', ...ModeConfig.all.map((mode) => mode.id)];
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _modeSheetTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...allModes.map((modeId) {
                final isSelected = modeId == _modeTag;
                final label = modeId.isEmpty ? _withoutModeLabel : _l10n.modeLabel(modeId);
                return ListTile(
                  onTap: () => Navigator.of(sheetContext).pop(modeId),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    modeId.isEmpty
                        ? Icons.block_rounded
                        : ModeConfig.all
                              .firstWhere((mode) => mode.id == modeId)
                              .icon,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.64),
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.74),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _modeTag = selected);
    }
  }

  Future<void> _pickLocation() async {
    final locationService = LocationService();
    final placesService = PlacesService();
    final manualController = TextEditingController(text: _locationLabel);
    final places = <Map<String, dynamic>>[];
    var loading = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> loadPlaces(StateSetter setSheetState) async {
          final position = await locationService.getCurrentPosition();
          if (position == null) {
            setSheetState(() => loading = false);
            return;
          }

          final results = await placesService.getNearbyPlaces(
            lat: position.latitude,
            lng: position.longitude,
            modeId: widget.initialModeId,
            radius: 1200,
          );
          if (!sheetContext.mounted) return;
          setSheetState(() {
            places
              ..clear()
              ..addAll(results.take(8));
            loading = false;
          });
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (loading && places.isEmpty) {
              Future.microtask(() => loadPlaces(setSheetState));
            }

            void selectLocation({
              required String label,
              required String placeId,
            }) {
              Navigator.of(sheetContext).pop();
              if (!mounted) return;
              setState(() {
                _locationLabel = label;
                _placeId = placeId;
              });
            }

            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 22,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _locationSheetTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.initialCity.isNotEmpty)
                    ListTile(
                      onTap: () => selectLocation(
                        label: widget.initialCity,
                        placeId: '',
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        widget.initialCity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _useCityLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                        ),
                      ),
                    ),
                  TextField(
                    controller: manualController,
                    maxLength: 160,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _manualLocationHint,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: AppColors.bgMain,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final manual = manualController.text.trim();
                        if (manual.isEmpty) return;
                        selectLocation(label: manual, placeId: '');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_useManualLocationLabel),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _nearbyPlacesLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (places.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        _noNearbyPlacesLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(sheetContext).size.height * 0.32,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: places.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withValues(alpha: 0.06),
                          height: 1,
                        ),
                        itemBuilder: (_, index) {
                          final place = places[index];
                          return ListTile(
                            onTap: () => selectLocation(
                              label: (place['name'] ?? '').toString(),
                              placeId: (place['place_id'] ?? '').toString(),
                            ),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.place_rounded,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              (place['name'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              (place['vicinity'] ?? '').toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      if (!mounted) return;
                      setState(() {
                        _locationLabel = '';
                        _placeId = '';
                      });
                    },
                    child: Text(
                      _removeLocationLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    manualController.dispose();
  }

  Future<void> _addMoreFromGallery() async {
    final picked = await _imagePicker.pickMultiImage(imageQuality: 92);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _files.addAll(picked.take(10 - _files.length));
      _pageIndex = _files.length - 1;
    });
    await _pageController.animateToPage(
      _pageIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _addMoreFromCamera() async {
    final captured = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (captured == null || !mounted) return;
    setState(() {
      if (_files.length < 10) {
        _files.add(captured);
        _pageIndex = _files.length - 1;
      }
    });
    if (_pageIndex < _files.length) {
      await _pageController.animateToPage(
        _pageIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleModeOverlay() {
    if (_modeTag.isEmpty) return;
    setState(() {
      _showModeOnCanvas = !_showModeOnCanvas;
      if (!_showModeOnCanvas && _selectedOverlay == 'mode') {
        _selectedOverlay = null;
      }
    });
  }

  void _toggleLocationOverlay() {
    if (_locationLabel.isEmpty) return;
    setState(() {
      _showLocationOnCanvas = !_showLocationOnCanvas;
      if (!_showLocationOnCanvas && _selectedOverlay == 'location') {
        _selectedOverlay = null;
      }
    });
  }

  void _updateAlignment(DragUpdateDetails details, BoxConstraints constraints) {
    final dx = details.delta.dx / (constraints.maxWidth / 2);
    final dy = details.delta.dy / (constraints.maxHeight / 2);
    setState(() {
      _textAlignment = Alignment(
        (_textAlignment.x + dx).clamp(-0.82, 0.82),
        (_textAlignment.y + dy).clamp(-0.78, 0.78),
      );
    });
  }

  void _finish() {
    final title = _titleController.text.trim();
    final safeTitle = title.characters.take(80).toString();
    final safeLocation = _locationLabel.trim().characters.take(160).toString();
    final safePlaceId = _placeId.trim().characters.take(160).toString();

    final argb = _textColor.toARGB32().toRadixString(16).padLeft(8, '0');
    final rgb = argb.substring(2).toUpperCase();

    Navigator.of(context).pop(
      StoryStatusDraft(
        files: _files,
        title: safeTitle,
        textColorHex: '#$rgb',
        textOffsetX: _textAlignment.x,
        textOffsetY: _textAlignment.y,
        modeTag: _modeTag,
        locationLabel: safeLocation,
        placeId: safePlaceId,
        showModeOverlay: _showModeOnCanvas,
        showLocationOverlay: _showLocationOnCanvas,
        publishKind: widget.publishKind,
        durationHours: widget.durationHours,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titlePreview = _titleController.text.trim();
    final modeColor = _modeTag.isEmpty
        ? AppColors.primary
        : ModeConfig.all
              .firstWhere(
                (mode) => mode.id == _modeTag,
                orElse: () => ModeConfig.all.first,
              )
              .color;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _files.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              return Image.file(
                File(_files[index].path),
                fit: BoxFit.cover,
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.52),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: _textAlignment,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            _updateAlignment(details, constraints),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (titlePreview.isNotEmpty)
                              _EditableTitleOverlay(
                                label: titlePreview,
                                color: _textColor,
                                selected: _selectedOverlay == 'title',
                                hovered: _titleHovered,
                                onTap: () {
                                  setState(() {
                                    _selectedOverlay = _selectedOverlay == 'title'
                                        ? null
                                        : 'title';
                                  });
                                },
                                onHoverChanged: (value) {
                                  setState(() => _titleHovered = value);
                                },
                                onRemove: () {
                                  setState(() {
                                    _titleController.clear();
                                    _selectedOverlay = null;
                                  });
                                },
                                maxWidth: constraints.maxWidth * 0.78,
                              ),
                            if (_showModeOnCanvas || _showLocationOnCanvas) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_showModeOnCanvas)
                                    _EditableMetaPill(
                                      icon: Icons.bolt_rounded,
                                      label: _l10n.modeLabel(_modeTag),
                                      color: modeColor,
                                      selected: _selectedOverlay == 'mode',
                                      hovered: _modeHovered,
                                      onTap: () {
                                        setState(() {
                                          _selectedOverlay =
                                              _selectedOverlay == 'mode' ? null : 'mode';
                                        });
                                      },
                                      onHoverChanged: (value) {
                                        setState(() => _modeHovered = value);
                                      },
                                      onRemove: () {
                                        setState(() {
                                          _showModeOnCanvas = false;
                                          _selectedOverlay = null;
                                        });
                                      },
                                    ),
                                  if (_showLocationOnCanvas)
                                    _EditableMetaPill(
                                      icon: Icons.place_rounded,
                                      label: _locationLabel,
                                      color: Colors.white,
                                      selected: _selectedOverlay == 'location',
                                      hovered: _locationHovered,
                                      onTap: () {
                                        setState(() {
                                          _selectedOverlay = _selectedOverlay == 'location'
                                              ? null
                                              : 'location';
                                        });
                                      },
                                      onHoverChanged: (value) {
                                        setState(() => _locationHovered = value);
                                      },
                                      onRemove: () {
                                        setState(() {
                                          _showLocationOnCanvas = false;
                                          _selectedOverlay = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              _TopIconButton(
                                icon: Icons.arrow_back_rounded,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const Spacer(),
                              _TopCountBadge(
                                label: '${_pageIndex + 1}/${_files.length}',
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _titleController,
                                maxLength: 80,
                                onChanged: (value) {
                                  setState(() {
                                    if (value.trim().isEmpty &&
                                        _selectedOverlay == 'title') {
                                      _selectedOverlay = null;
                                    }
                                  });
                                },
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _titleFieldHint,
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.32),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.title_rounded,
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.06),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 38,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _storyColors.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (_, index) {
                                    final color = _storyColors[index];
                                    final isSelected =
                                        color.toARGB32() == _textColor.toARGB32();
                                    return GestureDetector(
                                      onTap: () => setState(() => _textColor = color),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.32,
                                                  ),
                                            width: isSelected ? 2.4 : 1.2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetaActionButton(
                                      onPressed: _pickMode,
                                      icon: Icons.auto_awesome_rounded,
                                      label: _modeTag.isEmpty
                                          ? _addModeLabel
                                          : _l10n.modeLabel(_modeTag),
                                      accent: _modeTag.isEmpty ? null : modeColor,
                                      canAddToCanvas: _modeTag.isNotEmpty,
                                      addedToCanvas: _showModeOnCanvas,
                                      onAddToCanvas: _toggleModeOverlay,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MetaActionButton(
                                      onPressed: _pickLocation,
                                      icon: Icons.place_rounded,
                                      label: _locationLabel.isEmpty
                                          ? _addLocationLabel
                                          : _locationLabel,
                                      accent: _locationLabel.isEmpty
                                          ? null
                                          : AppColors.primary,
                                      canAddToCanvas: _locationLabel.isNotEmpty,
                                      addedToCanvas: _showLocationOnCanvas,
                                      onAddToCanvas: _toggleLocationOverlay,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _files.length >= 10
                                          ? null
                                          : _addMoreFromGallery,
                                      icon: const Icon(Icons.add_photo_alternate_outlined),
                                      label: Text(_galleryAddLabel),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.12),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 56,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _files.length >= 10
                                          ? null
                                          : _addMoreFromCamera,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.12),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Icon(Icons.photo_camera_outlined),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _finish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    _shareStoryLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _modeSheetTitle => switch (_l10n.languageCode) {
        'en' => 'Add your mode',
        'de' => 'Modus hinzufügen',
        _ => 'Modunu ekle',
      };

  String get _withoutModeLabel => switch (_l10n.languageCode) {
        'en' => 'No mode tag',
        'de' => 'Kein Modus',
        _ => 'Mod etiketi yok',
      };

  String get _locationSheetTitle => switch (_l10n.languageCode) {
        'en' => 'Add location or place',
        'de' => 'Ort oder Location hinzufügen',
        _ => 'Konum veya mekan ekle',
      };

  String get _useCityLabel => switch (_l10n.languageCode) {
        'en' => 'Use current area',
        'de' => 'Aktuellen Bereich verwenden',
        _ => 'Bulunduğum bölgeyi kullan',
      };

  String get _manualLocationHint => switch (_l10n.languageCode) {
        'en' => 'Write a custom location label',
        'de' => 'Eigene Ortsbezeichnung schreiben',
        _ => 'Özel bir konum etiketi yaz',
      };

  String get _useManualLocationLabel => switch (_l10n.languageCode) {
        'en' => 'Use this label',
        'de' => 'Dieses Label verwenden',
        _ => 'Bu etiketi kullan',
      };

  String get _nearbyPlacesLabel => switch (_l10n.languageCode) {
        'en' => 'Nearby places',
        'de' => 'Orte in der Nähe',
        _ => 'Yakındaki mekanlar',
      };

  String get _noNearbyPlacesLabel => switch (_l10n.languageCode) {
        'en' => 'No nearby place suggestion found.',
        'de' => 'Keine Orte in der Nähe gefunden.',
        _ => 'Yakında uygun mekan önerisi bulunamadı.',
      };

  String get _removeLocationLabel => switch (_l10n.languageCode) {
        'en' => 'Remove location',
        'de' => 'Ort entfernen',
        _ => 'Konumu kaldır',
      };

  String get _titleFieldHint => switch (_l10n.languageCode) {
        'en' => _isHighlightFlow ? 'Optional highlight title' : 'Optional story title',
        'de' => _isHighlightFlow ? 'Optionaler Highlight-Titel' : 'Optionaler Story-Titel',
        _ => _isHighlightFlow ? 'İsteğe bağlı highlight başlığı' : 'İsteğe bağlı durum başlığı',
      };

  String get _addModeLabel => switch (_l10n.languageCode) {
        'en' => 'Add mode',
        'de' => 'Modus hinzufügen',
        _ => 'Mod ekle',
      };

  String get _addLocationLabel => switch (_l10n.languageCode) {
        'en' => 'Add location',
        'de' => 'Ort hinzufügen',
        _ => 'Konum ekle',
      };

  String get _galleryAddLabel => switch (_l10n.languageCode) {
        'en' => 'Add photo',
        'de' => 'Foto hinzufügen',
        _ => 'Foto ekle',
      };

  String get _shareStoryLabel => switch (_l10n.languageCode) {
        'en' => _isHighlightFlow ? 'Save highlight' : 'Share story',
        'de' => _isHighlightFlow ? 'Highlight speichern' : 'Story teilen',
        _ => _isHighlightFlow ? 'Highlightı kaydet' : 'Durumu paylaş',
      };

}

class _EditableTitleOverlay extends StatelessWidget {
  const _EditableTitleOverlay({
    required this.label,
    required this.color,
    required this.selected,
    required this.hovered,
    required this.onTap,
    required this.onRemove,
    required this.onHoverChanged,
    required this.maxWidth,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool hovered;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<bool> onHoverChanged;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final showRemove = hovered || selected;
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: showRemove
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                  shadows: const [
                    Shadow(
                      blurRadius: 14,
                      color: Colors.black54,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
            if (showRemove)
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _TopCountBadge extends StatelessWidget {
  final String label;

  const _TopCountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EditableMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool hovered;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<bool> onHoverChanged;

  const _EditableMetaPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.hovered,
    required this.onTap,
    required this.onRemove,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showRemove = hovered || selected;
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: showRemove
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color == Colors.white ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (showRemove)
              Positioned(
                top: -7,
                right: -7,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback onAddToCanvas;
  final IconData icon;
  final String label;
  final Color? accent;
  final bool canAddToCanvas;
  final bool addedToCanvas;

  const _MetaActionButton({
    required this.onPressed,
    required this.onAddToCanvas,
    required this.icon,
    required this.label,
    required this.canAddToCanvas,
    required this.addedToCanvas,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = accent ?? Colors.white.withValues(alpha: 0.76);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent == null
              ? Colors.white.withValues(alpha: 0.12)
              : effectiveColor.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPressed,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Row(
                  children: [
                    Icon(icon, color: effectiveColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent == null ? Colors.white.withValues(alpha: 0.76) : effectiveColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          InkWell(
            onTap: canAddToCanvas ? onAddToCanvas : null,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(16),
            ),
            child: SizedBox(
              width: 42,
              height: 46,
              child: Icon(
                addedToCanvas ? Icons.check_rounded : Icons.add_rounded,
                color: canAddToCanvas
                    ? (addedToCanvas ? AppColors.success : AppColors.primary)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final BoxFit fit;

  const _AssetThumbnail({
    required this.asset,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize.square(720)),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(color: AppColors.bgSurface);
        }
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
