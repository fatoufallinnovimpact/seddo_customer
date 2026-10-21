import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestJsonAssetLoader extends AssetLoader {
  const TestJsonAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    if (file.existsSync()) {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }
    return {};
  }
}

Future<void> initTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

Widget wrapWithTestLocalization({
  required Widget child,
  Locale locale = const Locale('fr'),
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('fr'), Locale('wo')],
    path: 'assets/translations',
    assetLoader: const TestJsonAssetLoader(),
    fallbackLocale: const Locale('fr'),
    startLocale: locale,
    saveLocale: false,
    useOnlyLangCode: true,
    child: Builder(
      builder: (context) {
        return MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: child,
        );
      },
    ),
  );
}
