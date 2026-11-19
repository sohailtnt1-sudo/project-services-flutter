// Language switch (English | اردو) — one widget, used on the auth screen
// and in the AppBars of both shells. Tapping it shows a small menu;
// the choice is saved by the language service and the whole app
// rebuilds in the new language immediately.
import 'package:flutter/material.dart';
import '../services/language_service.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageService,
      builder: (context, lang, _) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.language),
          tooltip: 'English / اردو',
          onSelected: (code) => languageService.setLanguage(code),
          itemBuilder: (context) => [
            CheckedPopupMenuItem<String>(
              value: kLanguageEnglish,
              checked: lang == kLanguageEnglish,
              child: const Text('English'),
            ),
            CheckedPopupMenuItem<String>(
              value: kLanguageUrdu,
              checked: lang == kLanguageUrdu,
              child: const Text('اردو'),
            ),
          ],
        );
      },
    );
  }
}

/// Compact text toggle for screens without an AppBar (the auth screen):
/// shows the *other* language so one tap switches.
class LanguageTextToggle extends StatelessWidget {
  const LanguageTextToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageService,
      builder: (context, lang, _) {
        final other = lang == kLanguageUrdu ? kLanguageEnglish : kLanguageUrdu;
        final label = other == kLanguageUrdu ? 'اردو' : 'English';
        return TextButton.icon(
          onPressed: () => languageService.setLanguage(other),
          icon: const Icon(Icons.language, size: 18),
          label: Text(label),
        );
      },
    );
  }
}
