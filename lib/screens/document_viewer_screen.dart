import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/vaulted_file.dart';
import '../providers/vault_providers.dart';
import '../themes/app_colors.dart';
import '../utils/toast_utils.dart';

/// Document viewer for PDFs and text files
class DocumentViewerScreen extends ConsumerStatefulWidget {
  final VaultedFile file;

  const DocumentViewerScreen({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _decryptedData;
  String? _textContent;
  PdfViewerController? _pdfController;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _loadDocument();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.file.isEncrypted && widget.file.encryptionIv != null) {
        // Decrypt the file
        final data = await ref
            .read(vaultServiceProvider)
            .getDecryptedFileData(widget.file.id);
        if (data == null) {
          setState(() {
            _error = 'Failed to decrypt document';
            _isLoading = false;
          });
          return;
        }
        _decryptedData = data;
      }

      // Load text content for text files
      if (_isTextFile) {
        await _loadTextContent();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  bool get _isPdf =>
      widget.file.extension.toLowerCase() == 'pdf' ||
      widget.file.mimeType == 'application/pdf';

  bool get _isTextFile {
    final ext = widget.file.extension.toLowerCase();
    return ext == 'txt' ||
        ext == 'md' ||
        ext == 'json' ||
        ext == 'xml' ||
        ext == 'csv' ||
        ext == 'log' ||
        ext == 'rtf' ||
        widget.file.mimeType.startsWith('text/');
  }

  Future<void> _loadTextContent() async {
    try {
      if (_decryptedData != null) {
        _textContent = String.fromCharCodes(_decryptedData!);
      } else {
        final file = File(widget.file.vaultPath);
        _textContent = await file.readAsString();
      }
    } catch (e) {
      debugPrint('Error reading text file: $e');
      _textContent = 'Unable to read file content';
    }
  }

  void _toggleFavorite() async {
    await ref
        .read(vaultNotifierProvider.notifier)
        .toggleFavorite(widget.file.id);
    ToastUtils.showSuccess(
      widget.file.isFavorite ? 'Removed from favorites' : 'Added to favorites',
    );
  }

  Future<void> _exportToDownloads() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.lightBackground,
          content: Row(
            children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent)),
              const SizedBox(width: 20),
              Expanded(
                  child: Text('Exporting ${widget.file.originalName}...',
                      style: const TextStyle(fontFamily: 'ProductSans'))),
            ],
          ),
        ),
      );

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        if (mounted) Navigator.pop(context);
        ToastUtils.showError('Could not access Downloads folder');
        return;
      }

      final destinationPath =
          '${downloadsDir.path}/${widget.file.originalName}';
      final vaultService = ref.read(vaultServiceProvider);
      final exportedFile =
          await vaultService.exportFile(widget.file.id, destinationPath);

      if (mounted) Navigator.pop(context);

      if (exportedFile != null) {
        ToastUtils.showSuccess(
            'Exported to Downloads/${widget.file.originalName}');
      } else {
        ToastUtils.showError('Failed to export file');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error exporting file: $e');
      ToastUtils.showError('Failed to export file: $e');
    }
  }

  Future<void> _openWithExternalApp() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.lightBackground,
          content: Row(
            children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.accent)),
              const SizedBox(width: 20),
              Expanded(
                  child: Text('Preparing ${widget.file.originalName}...',
                      style: const TextStyle(fontFamily: 'ProductSans'))),
            ],
          ),
        ),
      );

      final vaultService = ref.read(vaultServiceProvider);
      final decryptedFile = await vaultService.getVaultedFile(widget.file.id);

      if (mounted) Navigator.pop(context);

      if (decryptedFile != null && await decryptedFile.exists()) {
        final result = await OpenFilex.open(decryptedFile.path);
        if (result.type != ResultType.done) {
          ToastUtils.showError('No app found to open this file type');
        }
      } else {
        ToastUtils.showError('Failed to prepare file');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error opening file: $e');
      ToastUtils.showError('Failed to open file: $e');
    }
  }

  void _showFileInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
                fontFamily: 'ProductSans',
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', widget.file.originalName),
            _buildInfoRow('Type', widget.file.extension.toUpperCase()),
            _buildInfoRow('Size', widget.file.formattedSize),
            _buildInfoRow('Added', widget.file.formattedDateAdded),
            if (widget.file.isEncrypted) _buildInfoRow('Encrypted', 'Yes'),
            if (_isPdf && _totalPages > 0)
              _buildInfoRow('Pages', _totalPages.toString()),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.originalName,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_isPdf && _totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 12,
                  color: AppColors.lightTextTertiary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.file.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: widget.file.isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showFileInfo,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              'Loading document...',
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'ProductSans',
                color: AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isPdf) {
      return _buildPdfViewer();
    } else if (_isTextFile) {
      return _buildTextViewer();
    } else {
      return _buildUnsupportedViewer();
    }
  }

  Widget _buildPdfViewer() {
    final pdfData =
        _decryptedData ?? File(widget.file.vaultPath).readAsBytesSync();

    return PdfViewer.data(
      pdfData,
      sourceName: widget.file.originalName,
      controller: _pdfController,
      params: PdfViewerParams(
        pageDropShadow: BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
        onViewerReady: (document, controller) {
          setState(() {
            _totalPages = document.pages.length;
          });
        },
        onPageChanged: (page) {
          setState(() {
            _currentPage = page ?? 1;
          });
        },
      ),
    );
  }

  Widget _buildTextViewer() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _textContent ?? 'No content',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: AppColors.lightTextPrimary,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getDocumentIcon(),
            size: 80,
            color: _getDocumentColor(),
          ),
          const SizedBox(height: 24),
          Text(
            widget.file.originalName,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.file.formattedSize,
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getDocumentColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.file.extension.toUpperCase(),
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontWeight: FontWeight.w600,
                color: _getDocumentColor(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Preview not available for this document type',
            style: TextStyle(
              fontFamily: 'ProductSans',
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _exportToDownloads,
                icon: const Icon(Icons.download),
                label: const Text('Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _openWithExternalApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with...'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  side: BorderSide(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon() {
    switch (widget.file.extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentColor() {
    switch (widget.file.extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
      case 'md':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}
