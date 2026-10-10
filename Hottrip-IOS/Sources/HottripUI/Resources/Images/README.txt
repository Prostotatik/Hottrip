Растровые ассеты (PNG/JPG). Кладите сюда файлы с именами слотов, например `home-hero.jpg`, `dest-turkey.jpg`,
`tour-t1-1.jpg`, `tour-t1-cover.jpg` (обложка = кроп `tour-t1-1`, иначе зум-переход подменит картинку).
Полный список слотов и размеров — `_workspace/asseter/asset-plan-iter07.md`.
Загружаются через HTImage(name:) -> Bundle.module (без .xcassets: actool недоступен в Command Line Tools).
Нет файла — рисуется кодовая заглушка (DesignSystem/HTImage.swift).
