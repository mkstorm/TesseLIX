import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const TesseLix());
}

class TesseLix extends StatelessWidget {
  const TesseLix({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TesseLix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MainPage(title: 'Beregn Lix Tal'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String? _ocrResult;
  double? _lixResult;
  bool _isLoading = false;
  final tesseractConfig = OCRConfig(language: 'eng+dan');

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _ocrResult = null;
    });

    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Beskær Billede',
              // Instead of aspectRatioPresets, use:
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(title: 'Beskær Billede'),
          ],
        );

        final imagePath = croppedFile?.path;
        if (imagePath != null) {
          try {
            final bwImagePath = await processImageToBW(imagePath);
            _ocrResult = await TesseractOcr.extractText(
              bwImagePath,
              config: tesseractConfig,
            );
          } catch (e) {
            setState(() {
              _ocrResult = "Kunne ikke udtrække tekst: $e";
            });
          }

          if (_ocrResult != null) {
            String text = _ocrResult as String;
            final lix = calculateLIX(text);
            setState(() {
              _ocrResult = text;
              _lixResult = lix;
            });
          } else {
            setState(() {
              _ocrResult = "Tekst ikke fundet";
            });
          }
        } else {
          setState(() {
            _ocrResult = "Billede ikke beskåret";
          });
        }
      } catch (e) {
        setState(() {
          _ocrResult = "Kunne ikke beskære $e";
        });
      }
    } else {
      setState(() {
        _ocrResult = "Intet Billede fundet";
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<String> processImageToBW(String originalPath) async {
    final bytes = await File(originalPath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception("Cannot decode image");
    image = img.grayscale(image);
    img.Image rgbImage = img.copyResize(
      image, // no size change, but copies as RGB
      width: image.width,
      height: image.height,
      interpolation: img.Interpolation.nearest,
    );

    rgbImage = img.adjustColor(rgbImage, contrast: 1.5);

    final tempFile = File('${originalPath}_bw.jpg');
    await tempFile.writeAsBytes(img.encodeJpg(rgbImage, quality: 95));
    print(
      'Saved processed image: ${tempFile.path} size: ${await tempFile.length()}',
    );
    return tempFile.path;
  }

  double calculateLIX(String text) {
    final wordMatches = RegExp(
      r"\b[\wæøåÆØÅ]+\b",
      unicode: true,
    ).allMatches(text);
    final words = wordMatches.length;
    final sentences = RegExp(r"[.!?]", unicode: true).allMatches(text).length;
    final longWords = wordMatches.where((m) => m.group(0)!.length >= 7).length;
    if (sentences == 0 || words == 0) return 0.0;
    return (words / sentences) + ((longWords * 100) / words);
  }

  void _showImageSourceOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _showImageSourceOptions(context),
              child: const Text('Vælg Billede eller Kamera'),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_ocrResult != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _ocrResult!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'LIX-tal: ${_lixResult?.toStringAsFixed(2) ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
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
}
