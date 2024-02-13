import 'package:rfw/rfw.dart';

Map<LibraryName, LocalWidgetLibrary> createLocalWidgetsMap() {
  const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  const LibraryName materialName = LibraryName(<String>['material', 'widgets']);
  Map<LibraryName, LocalWidgetLibrary> localWidgets = {};

  localWidgets[coreName] = createCoreWidgets();
  localWidgets[materialName] = createMaterialWidgets();

  return localWidgets;
}
