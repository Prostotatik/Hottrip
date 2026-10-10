# Hottrip iOS (UI-демо)

Агрегатор горящих туров (Узбекистан, цены в UZS, вылет из Ташкента). Только UI на моках.

## Структура
```
Package.swift                 Swift Package: библиотека HottripUI + macOS-утилита HottripSnapshots
Sources/HottripUI/
  DesignSystem/               токены (цвета/шрифты/отступы), режим рендера, HTImage
  Components/                 HTScroll, HTScreen/NavBar/BottomBar, кнопки, таб-бар, таймер, рамка устройства
  Screens/                    Главная, Поиск, Результаты, Тур, Оплата, Успех, Избранное, Профиль
  Models/                     модели, форматтеры UZS/дат, MockData
  Navigation/                 AppRouter, HottripRootView/TabShell, SnapshotCatalog, StatusBar, DemoLaunch
  Resources/Images/           растровые ассеты (PNG/JPG, без .xcassets)
Sources/HottripSnapshots/     рендер экранов в PNG (ImageRenderer)
App/                          iOS-оболочка на UIKit (AppDelegate/SceneDelegate, стиль строки состояния), Info.plist, Assets.xcassets
HottripUITests/               XCUITest-сценарии для видео интеракций
project.yml                   спецификация XcodeGen
Hottrip.xcodeproj             сгенерирован XcodeGen из project.yml
scripts/snapshot.sh           сборка + рендер снапшотов (macOS, вспомогательные)
scripts/sim-shots.sh          сборка под симулятор + скриншоты/видео (основные)
```

## Симулятор (Xcode 27)
```
./scripts/sim-shots.sh                 # все экраны → ../_workspace/shared/sim-shots
./scripts/sim-shots.sh --ui all        # видео UI-сценариев
```
Демо-запуск любого экрана: `-demoScreen tour -demoState operatorCoral`. Подробно: `../_workspace/developer/HOW_TO_SIM.md`.

## Снапшоты (без Xcode)
```
./scripts/snapshot.sh                 # всё → ../_workspace/shared/snapshots
./scripts/snapshot.sh --only 04-tour  # один экран
```
Подробно: `../_workspace/developer/HOW_TO_SNAPSHOT.md`.

Только сборка пакета без Xcode (CLT: SDK macOS 27 без плагина SwiftUIMacros, поэтому SDK 26.5):
```
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build
```

## Открыть в Xcode
1. Установить Xcode 16+ (iOS 17 SDK+).
2. `open Hottrip.xcodeproj` → схема **Hottrip** → симулятор iPhone 16 Pro → Run.
   Проект ссылается на этот же каталог как на локальный Swift Package (`HottripUI`).
3. Для запуска на устройстве выбрать свою команду в Signing & Capabilities.

Если меняли `project.yml` — перегенерировать: `brew install xcodegen && xcodegen generate`.
Info.plist генерируется из `project.yml` (секция `info.properties`) — правьте там.

Альтернатива без xcodeproj: `open Package.swift` покажет пакет (превью SwiftUI работают), но
iOS-приложение (`App/`) собирается только через Hottrip.xcodeproj.
