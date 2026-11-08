import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'dashboard.dart';
import 'dashboard_model.dart';
import 'data/repository.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield const LicenseEntryWithLineBreaks(
      ['Natural Earth'],
      'Public domain. Made with Natural Earth. https://www.naturalearthdata.com/about/terms-of-use/',
    );
  });
  runApp(const TyphoonApp());
}

class TyphoonApp extends StatefulWidget {
  const TyphoonApp({super.key});
  @override
  State<TyphoonApp> createState() => _TyphoonAppState();
}

class _TyphoonAppState extends State<TyphoonApp> {
  final model = DashboardModel(repository: TyphoonRepository());
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '台风观察',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: DashboardScreen(model: model),
  );
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }
}
