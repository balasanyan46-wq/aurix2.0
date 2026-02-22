# Тестирование responsive AURIX

## Как проверить

### iPhone (симулятор)
```bash
flutter run -d iphone
```
Или выбрать устройство:
```bash
flutter devices
flutter run -d <device_id>
```

### Chrome с узкой шириной
```bash
flutter run -d chrome
```
В Chrome: DevTools → Toggle device toolbar (Ctrl+Shift+M) → выбрать iPhone или задать width 390px.

### Проверка breakpoint
- **< 900px**: Drawer (☰ hamburger), compact UI, TabBar в Legal detail
- **>= 900px**: Sidebar слева, grid, две колонки

## Что проверять
1. **Drawer**: На мобиле — кнопка ☰ слева в TopBar открывает меню
2. **Legal list**: На мобиле — карточки в одну колонку (иконка | title/desc | chevron)
3. **Legal detail**: На мобиле — TabBar [Форма] [Просмотр], внизу фиксированная панель с кнопками
4. **Диалоги**: На мобиле — ширина экран−32, прокручиваемый контент
5. **Без overflow**: Никаких RenderFlex/BOTTOM OVERFLOWED баннеров
