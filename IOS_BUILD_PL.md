# RON Hex — build na iPhone (instrukcja)

Preset `iOS` jest w `export_presets.cfg` (bundle `com.konradbolek.ronhex`, iOS 14+, poziomo, eksport jako projekt Xcode).

## Czego brakuje na Macu (stan 27.10.2026)
1. **Xcode** — zainstaluj z App Store, potem: `sudo xcode-select -s /Applications/Xcode.app` i jednorazowo otwórz Xcode (komponenty).
2. **Szablony eksportu Godot 4.7.2** — Godot → Editor → Manage Export Templates → Download and Install.
3. **Konto Apple** — darmowe Apple ID wystarczy do instalacji na własnym telefonie (aplikacja wygasa po 7 dniach); płatne Apple Developer (99 USD/rok) — TestFlight.

## Kroki
1. Godot → Project → Export → iOS → wpisz **App Store Team ID** (Xcode → Settings → Accounts → Twoje Apple ID → Team; ID z developer.apple.com → Membership).
2. Export Project → `build/ios/` → powstanie `RonHex.xcodeproj`.
3. Otwórz w Xcode → target → Signing & Capabilities → zaznacz *Automatically manage signing*, wybierz Team.
4. Podłącz iPhone kablem, na telefonie włącz **Tryb dewelopera** (Ustawienia → Prywatność i ochrona → Tryb dewelopera).
5. Wybierz iPhone jako cel → ▶ Run. Za pierwszym razem: Ustawienia → Ogólne → VPN i urządzenia → zaufaj certyfikatowi.

Lub z terminala po wpisaniu Team ID:
`~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug "iOS" build/ios/RonHex.xcodeproj`

## Sterowanie dotykiem
- Tap = klik (ruch, wybór, atak).
- Przeciągnięcie jednym palcem = przesuwanie mapy, dwa palce = zoom.
- Menu/pauza: przycisk „Menu” w prawym panelu (brak Esc). Zapis/wczytanie: przyciski w panelu.
