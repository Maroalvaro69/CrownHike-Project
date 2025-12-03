import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crownhike_app/auth/register_screen.dart';

void main() {
  testWidgets('Funkcjonalny test rejestracji: Walidacja krótkiego hasła', (
    WidgetTester tester,
  ) async {
    // 1. Uruchom ekran rejestracji (wirtualnie)
    // Używamy MaterialApp, żeby zapewnić kontekst dla stylów i nawigacji
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    // 2. Znajdź przycisk rejestracji
    final button = find.text('Zarejestruj się');

    // 3. AKCJA: Wpisz za krótkie hasło
    // Szukamy pola, które jest typu TextFormField i ma etykietę lub hint
    // Najbezpieczniej szukać po typie widgetu, jeśli mamy ich kilka,
    // ale tutaj użyjemy find.byType i wpiszemy dane w odpowiedniej kolejności.

    // Znajdujemy wszystkie pola tekstowe
    final textFields = find.byType(TextFormField);

    // Zakładamy kolejność z formularza: 0: Imię, 1: E-mail, 2: Hasło, 3: Potwierdź hasło
    await tester.enterText(textFields.at(0), 'TestUser'); // Imię
    await tester.enterText(textFields.at(1), 'test@test.pl'); // E-mail
    await tester.enterText(textFields.at(2), '123'); // Hasło (ZA KRÓTKIE!)
    await tester.enterText(textFields.at(3), '123'); // Potwierdzenie

    // 4. Kliknij przycisk
    await tester.tap(button);

    // 5. Czekamy na przerysowanie ekranu (animacje błędów)
    await tester.pump();

    // 6. ASERCJA: Sprawdź czy pojawił się tekst błędu
    // Szukamy tekstu, który Twoja walidacja zwraca dla krótkiego hasła
    expect(find.text('Hasło musi mieć min. 6 znaków'), findsOneWidget);
  });
}
