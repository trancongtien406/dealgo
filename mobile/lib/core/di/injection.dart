import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

export 'injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(initializerName: 'init')
Future<void> configureInjectable() async => getIt.init();

/// Registers generated leaf services on any [GetIt] instance (including tests).
void initInjectableOn(GetIt locator) => locator.init();
